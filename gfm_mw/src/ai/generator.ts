import type { Content } from "@google/generative-ai";
import type { Logger } from "pino";
import * as Sentry from "@sentry/node";
import { aiProvider, AiError } from "../infrastructure/ai";
import { fetchUrls, FetchError } from "../infrastructure/url-fetcher/url-fetcher";
import { HttpError } from "../presentation/middleware/error.middleware";
import { AiGenerationRepository } from "../domain/repositories/ai-generation.repository";
import { UserRepository } from "../domain/repositories/user.repository";
import { parseAndAutoRepair } from "./auto-repair";
import { FormSchema, GeneratedForm } from "./form-schema";
import { isFatal, isFallbackForm, formatZodErrors } from "./repair-policy";
import { buildContents } from "./build-contents";
import { SimpleForm, FORM_RESPONSE_SCHEMA, QUIZ_RESPONSE_SCHEMA } from "./simple-schema";
import { normalizeForm } from "./normalizer";
import { SYSTEM_PROMPT_FORM, SYSTEM_PROMPT_QUIZ, PROMPT_VERSION } from "./system-prompt";
import type { GenerateRequest } from "./request-schema";
import { geminiRequestsTotal } from "../infrastructure/metrics";

// File-based inputs (YouTube, PDF, book) require Gemini to ingest binary content — give them more time.
const YOUTUBE_DEADLINE_MS = 180_000;
const FILE_DEADLINE_MS    = 120_000;

interface GenerateArgs {
  user: { id: number; tier: "free" | "premium" };
  body: GenerateRequest;
  rowId: number;            // ai_generations.id (already 'processing' — caller owns it)
  generationId: string;
  quotaCost: number;        // quota units to deduct on success (>1 for large PDFs/books)
  aiRepo: AiGenerationRepository;
  userRepo: UserRepository;
  log: Logger;
}

export interface GenerationOutcome {
  generationId: string;
  form: GeneratedForm;
  inputTokens: number;
  outputTokens: number;
}

interface GeminiAttempt {
  rawText: string;
  inputTokens: number;
  outputTokens: number;
}

function sumTokens(a: GeminiAttempt, b: GeminiAttempt): GeminiAttempt {
  return {
    rawText: b.rawText,
    inputTokens: a.inputTokens + b.inputTokens,
    outputTokens: a.outputTokens + b.outputTokens,
  };
}

// Wire-level error codes are kept as `gemini_*` for Flutter compatibility
// (lib/features/ai_form_builder/data/datasources/ai_form_datasource.dart keys
// off these strings) regardless of the underlying AI provider.
function aiErrorToHttp(e: AiError): HttpError {
  switch (e.reason) {
    case "ai_timeout":
      return new HttpError(503, "gemini_timeout", "The AI is taking longer than expected.");
    case "ai_unavailable":
      return new HttpError(503, "gemini_unavailable", "The AI service is temporarily unavailable.");
    case "ai_blocked":
      // Safety filter triggered. The user input itself was rejected, not a
      // schema-validation problem — but `validation_error` is the closest
      // catalog entry the Flutter client renders ("try rephrasing"). See
      // feature-spec-flutter.md §4.
      return new HttpError(503, "validation_error", "The AI couldn't produce a result for this input. Please try rephrasing.");
  }
}

export async function runGeneration(args: GenerateArgs): Promise<GenerationOutcome> {
  const { body, log, aiRepo, rowId, generationId } = args;

  // ── Step A: Fetch URLs (only for inputType=urls) ──────────────────────────
  let fetchedUrls: { url: string; text: string }[] | undefined;
  if (body.inputType === "urls") {
    try {
      fetchedUrls = await fetchUrls(body.urls);
    } catch (e) {
      if (e instanceof FetchError) {
        log.warn({ reason: e.reason, details: e.details }, "url_fetch_failed");
        await aiRepo.updateFailure(rowId, {
          status: "validation_error",
          errorPayload: {
            reason: "url_fetch_failed",
            fetchReason: e.reason,
            details: e.details,
            promptVersion: PROMPT_VERSION,
          },
        });
        throw new HttpError(400, "url_fetch_failed", "Failed to fetch URL.", {
          url: typeof e.details["url"] === "string"
            ? (e.details["url"] as string)
            : body.urls[0]!,
          reason: e.reason,
        });
      }
      throw e;
    }
  }

  const contents = buildContents({ body, fetchedUrls });
  const systemPrompt = body.isQuiz ? SYSTEM_PROMPT_QUIZ : SYSTEM_PROMPT_FORM;
  const responseSchema = body.isQuiz ? QUIZ_RESPONSE_SCHEMA : FORM_RESPONSE_SCHEMA;
  const deadlineMs =
    body.inputType === "youtube" ? YOUTUBE_DEADLINE_MS :
    body.inputType === "pdf" || body.inputType === "book" ? FILE_DEADLINE_MS :
    undefined;

  // ── Step B: First AI attempt ──────────────────────────────────────────────
  let attempt1: GeminiAttempt;
  try {
    attempt1 = await aiProvider.call({
      contents,
      systemInstruction: systemPrompt,
      responseSchema: responseSchema,
      deadlineMs,
    });
  } catch (e) {
    if (e instanceof AiError) {
      const inputTokens  = typeof e.details["inputTokens"]  === "number" ? e.details["inputTokens"]  : undefined;
      const outputTokens = typeof e.details["outputTokens"] === "number" ? e.details["outputTokens"] : undefined;
      await aiRepo.updateFailure(rowId, {
        status: "gemini_error",
        errorPayload: {
          reason: e.reason,
          details: e.details,
          attempt: 1,
          promptVersion: PROMPT_VERSION,
          provider: aiProvider.name,
        },
        inputTokens,
        outputTokens,
      });
      if (e.reason === "ai_unavailable") {
        Sentry.withScope((scope) => {
          scope.setLevel("warning");
          scope.setTag("route", "POST /ai/generate");
          scope.setTag("input_type", body.inputType);
          scope.setTag("quota_tier", args.user.tier);
          scope.setTag("ai_provider", aiProvider.name);
          scope.setExtra("generation_id", generationId);
          scope.setExtra("ai_attempts", 1);
          Sentry.captureException(e);
        });
      }
      throw aiErrorToHttp(e);
    }
    throw e;
  }

  // ── Step C: Parse simple format → normalize → validate with FormSchema ───────
  // Parse raw JSON before auto-repair, which uppercases some simple type names
  // (e.g. "dropdown"→"DROPDOWN") and would break SimpleForm.safeParse.
  let rawJson1: unknown = null;
  try { rawJson1 = JSON.parse(attempt1.rawText.trim()); } catch { /* non-JSON */ }
  const simple1 = rawJson1 ? SimpleForm.safeParse(rawJson1) : null;

  let candidate1: unknown;
  let rules1: string[];
  let normalized1: unknown;

  if (simple1?.success) {
    normalized1 = normalizeForm(simple1.data);
    candidate1 = rawJson1;
    rules1 = [];
  } else {
    ({ candidate: candidate1, appliedRules: rules1 } = parseAndAutoRepair(attempt1.rawText));
    normalized1 = candidate1;
  }
  const zod1 = FormSchema.safeParse(normalized1);

  if (zod1.success) {
    log.info({ attempt: 1, autoRepairs: rules1 }, "gen_first_attempt_success");
    return finalize(args, zod1.data, attempt1);
  }

  // ── Step D: Fatal? → reject without a repair turn ─────────────────────────
  if (isFatal(zod1.error, candidate1)) {
    const fallback = isFallbackForm(candidate1);
    log.warn(
      { autoRepairs: rules1, zodIssueCount: zod1.error.issues.length, isFallback: fallback },
      "gen_fatal_first_attempt",
    );
    await aiRepo.updateFailure(rowId, {
      status: "validation_error",
      errorPayload: {
        reason: "fatal_on_first_attempt",
        promptVersion: PROMPT_VERSION,
        attempts: [{
          rawText: attempt1.rawText,
          zodIssues: zod1.error.issues,
          autoRepairs: rules1,
        }],
      },
      inputTokens: attempt1.inputTokens,
      outputTokens: attempt1.outputTokens,
    });
    geminiRequestsTotal.inc({ outcome: fallback ? "fallback_detected" : "validation_error" });
    Sentry.withScope((scope) => {
      scope.setLevel("warning");
      scope.setTag("route", "POST /ai/generate");
      scope.setTag("input_type", body.inputType);
      scope.setTag("quota_tier", args.user.tier);
      scope.setExtra("generation_id", generationId);
      scope.setExtra("gemini_attempts", 1);
      scope.setExtra("validation_error", formatZodErrors(zod1.error));
      scope.setExtra("raw_output_1", attempt1.rawText.slice(0, 5_000));
      Sentry.captureException(new Error("gemini_validation_error_fatal"));
    });
    throw new HttpError(503, "validation_error", "The AI produced an unexpected result. Please try again, or try rephrasing your input.");
  }

  // ── Step E: Repair turn ───────────────────────────────────────────────────
  log.info(
    { attempt: 1, autoRepairs: rules1, zodIssueCount: zod1.error.issues.length },
    "gen_first_attempt_failed_attempting_repair",
  );

  const repairContents: Content[] = [
    ...contents,
    { role: "model", parts: [{ text: attempt1.rawText }] },
    {
      role: "user",
      parts: [{
        text:
          "REPAIR: Your previous output failed validation with these errors. " +
          "Re-emit the SAME form with only these problems fixed. Output JSON only.\n\n" +
          formatZodErrors(zod1.error),
      }],
    },
  ];

  let attempt2: GeminiAttempt;
  try {
    attempt2 = await aiProvider.call({
      contents: repairContents,
      systemInstruction: systemPrompt,
      responseSchema: responseSchema,
      deadlineMs,
    });
  } catch (e) {
    if (e instanceof AiError) {
      const inputTokens  = typeof e.details["inputTokens"]  === "number" ? e.details["inputTokens"]  : undefined;
      const outputTokens = typeof e.details["outputTokens"] === "number" ? e.details["outputTokens"] : undefined;
      await aiRepo.updateFailure(rowId, {
        status: "gemini_error",
        errorPayload: {
          reason: e.reason,
          details: e.details,
          attempt: 2,
          promptVersion: PROMPT_VERSION,
          provider: aiProvider.name,
          firstAttempt: { rawText: attempt1.rawText, zodIssues: zod1.error.issues, autoRepairs: rules1 },
        },
        // Tokens from attempt 1 are sunk cost; attempt 2 may have produced
        // partial tokens before failing — we only get the count from the
        // AiError details if the model did emit something.
        inputTokens:  attempt1.inputTokens  + (inputTokens  ?? 0),
        outputTokens: attempt1.outputTokens + (outputTokens ?? 0),
      });
      if (e.reason === "ai_unavailable") {
        Sentry.withScope((scope) => {
          scope.setLevel("warning");
          scope.setTag("route", "POST /ai/generate");
          scope.setTag("input_type", body.inputType);
          scope.setTag("quota_tier", args.user.tier);
          scope.setTag("ai_provider", aiProvider.name);
          scope.setExtra("generation_id", generationId);
          scope.setExtra("ai_attempts", 2);
          Sentry.captureException(e);
        });
      }
      throw aiErrorToHttp(e);
    }
    throw e;
  }

  // ── Step F: Parse simple format → normalize → validate on repair output ──────
  let rawJson2: unknown = null;
  try { rawJson2 = JSON.parse(attempt2.rawText.trim()); } catch { /* non-JSON */ }
  const simple2 = rawJson2 ? SimpleForm.safeParse(rawJson2) : null;

  let candidate2: unknown;
  let rules2: string[];
  let normalized2: unknown;

  if (simple2?.success) {
    normalized2 = normalizeForm(simple2.data);
    candidate2 = rawJson2;
    rules2 = [];
  } else {
    ({ candidate: candidate2, appliedRules: rules2 } = parseAndAutoRepair(attempt2.rawText));
    normalized2 = candidate2;
  }
  const zod2 = FormSchema.safeParse(normalized2);
  const totalTokens = sumTokens(attempt1, attempt2);

  if (zod2.success) {
    log.info(
      { autoRepairs: { first: rules1, second: rules2 } },
      "gen_repair_success",
    );
    return finalize(args, zod2.data, totalTokens);
  }

  // ── Step G: Repair failed → reject ────────────────────────────────────────
  log.warn(
    {
      firstAutoRepairs: rules1,
      secondAutoRepairs: rules2,
      zodIssueCount: zod2.error.issues.length,
    },
    "gen_repair_failed",
  );
  await aiRepo.updateFailure(rowId, {
    status: "validation_error",
    errorPayload: {
      reason: "repair_failed",
      promptVersion: PROMPT_VERSION,
      attempts: [
        { rawText: attempt1.rawText, zodIssues: zod1.error.issues, autoRepairs: rules1 },
        { rawText: attempt2.rawText, zodIssues: zod2.error.issues, autoRepairs: rules2 },
      ],
    },
    inputTokens:  totalTokens.inputTokens,
    outputTokens: totalTokens.outputTokens,
  });
  geminiRequestsTotal.inc({ outcome: "validation_error" });
  Sentry.withScope((scope) => {
    scope.setLevel("warning");
    scope.setTag("route", "POST /ai/generate");
    scope.setTag("input_type", body.inputType);
    scope.setTag("quota_tier", args.user.tier);
    scope.setExtra("generation_id", generationId);
    scope.setExtra("gemini_attempts", 2);
    scope.setExtra("validation_error", formatZodErrors(zod2.error));
    scope.setExtra("raw_output_1", attempt1.rawText.slice(0, 3_000));
    scope.setExtra("raw_output_2", attempt2.rawText.slice(0, 3_000));
    Sentry.captureException(new Error("gemini_validation_error_repair_failed"));
  });
  throw new HttpError(503, "validation_error", "The AI produced an unexpected result. Please try again, or try rephrasing your input.");
}

async function finalize(
  args: GenerateArgs,
  form: GeneratedForm,
  tokens: GeminiAttempt,
): Promise<GenerationOutcome> {
  const { aiRepo, rowId, generationId } = args;

  await aiRepo.updateSuccess(rowId, {
    outputJson: form,
    inputTokens:  tokens.inputTokens,
    outputTokens: tokens.outputTokens,
  });

  return {
    generationId,
    form,
    inputTokens:  tokens.inputTokens,
    outputTokens: tokens.outputTokens,
  };
}
