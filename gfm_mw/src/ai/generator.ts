import type { Content } from "@google/generative-ai";
import type { Logger } from "pino";
import { callGemini, GeminiError } from "../infrastructure/gemini/gemini-client";
import { fetchUrls, FetchError } from "../infrastructure/url-fetcher/url-fetcher";
import { HttpError } from "../presentation/middleware/error.middleware";
import { AiGenerationRepository } from "../domain/repositories/ai-generation.repository";
import { UserRepository } from "../domain/repositories/user.repository";
import { parseAndAutoRepair } from "./auto-repair";
import { FormSchema, GeneratedForm } from "./form-schema";
import { isFatal, isFallbackForm, formatZodErrors } from "./repair-policy";
import { buildContents } from "./build-contents";
import { GEMINI_RESPONSE_SCHEMA } from "./response-schema";
import { SYSTEM_PROMPT_V1, PROMPT_VERSION } from "./system-prompt";
import type { GenerateRequest } from "./request-schema";

interface GenerateArgs {
  user: { id: number; tier: "free" | "premium" };
  body: GenerateRequest;
  rowId: number;            // ai_generations.id (already 'processing' — caller owns it)
  generationId: string;
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

function geminiErrorToHttp(e: GeminiError): HttpError {
  switch (e.reason) {
    case "gemini_timeout":
      return new HttpError(503, "gemini_timeout", "The AI is taking longer than expected.");
    case "gemini_unavailable":
      return new HttpError(503, "gemini_unavailable", "The AI service is temporarily unavailable.");
    case "gemini_blocked":
      // Safety filter triggered. The user input itself was rejected, not a
      // schema-validation problem — but `validation_error` is the closest
      // catalog entry the Flutter client renders ("try rephrasing"). See
      // feature-spec-flutter.md §4.
      return new HttpError(503, "validation_error", "The AI couldn't produce a result for this input. Please try rephrasing.");
  }
}

export async function runGeneration(args: GenerateArgs): Promise<GenerationOutcome> {
  const { body, log, aiRepo, rowId } = args;

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

  // ── Step B: First Gemini attempt ──────────────────────────────────────────
  let attempt1: GeminiAttempt;
  try {
    attempt1 = await callGemini({
      contents,
      systemInstruction: SYSTEM_PROMPT_V1,
      responseSchema: GEMINI_RESPONSE_SCHEMA,
    });
  } catch (e) {
    if (e instanceof GeminiError) {
      const inputTokens  = typeof e.details["inputTokens"]  === "number" ? e.details["inputTokens"]  : undefined;
      const outputTokens = typeof e.details["outputTokens"] === "number" ? e.details["outputTokens"] : undefined;
      await aiRepo.updateFailure(rowId, {
        status: "gemini_error",
        errorPayload: {
          reason: e.reason,
          details: e.details,
          attempt: 1,
          promptVersion: PROMPT_VERSION,
        },
        inputTokens,
        outputTokens,
      });
      throw geminiErrorToHttp(e);
    }
    throw e;
  }

  // ── Step C: Auto-repair + Zod ──────────────────────────────────────────────
  const { candidate: candidate1, appliedRules: rules1 } = parseAndAutoRepair(attempt1.rawText);
  const zod1 = FormSchema.safeParse(candidate1);

  if (zod1.success) {
    log.info({ attempt: 1, autoRepairs: rules1 }, "gen_first_attempt_success");
    return finalize(args, zod1.data, attempt1);
  }

  // ── Step D: Fatal? → reject without a repair turn ─────────────────────────
  if (isFatal(zod1.error, candidate1)) {
    log.warn(
      { autoRepairs: rules1, zodIssueCount: zod1.error.issues.length, isFallback: isFallbackForm(candidate1) },
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
    attempt2 = await callGemini({
      contents: repairContents,
      systemInstruction: SYSTEM_PROMPT_V1,
      responseSchema: GEMINI_RESPONSE_SCHEMA,
    });
  } catch (e) {
    if (e instanceof GeminiError) {
      const inputTokens  = typeof e.details["inputTokens"]  === "number" ? e.details["inputTokens"]  : undefined;
      const outputTokens = typeof e.details["outputTokens"] === "number" ? e.details["outputTokens"] : undefined;
      await aiRepo.updateFailure(rowId, {
        status: "gemini_error",
        errorPayload: {
          reason: e.reason,
          details: e.details,
          attempt: 2,
          promptVersion: PROMPT_VERSION,
          firstAttempt: { rawText: attempt1.rawText, zodIssues: zod1.error.issues, autoRepairs: rules1 },
        },
        // Tokens from attempt 1 are sunk cost; attempt 2 may have produced
        // partial tokens before failing — we only get the count from the
        // GeminiError details if the model did emit something.
        inputTokens:  attempt1.inputTokens  + (inputTokens  ?? 0),
        outputTokens: attempt1.outputTokens + (outputTokens ?? 0),
      });
      throw geminiErrorToHttp(e);
    }
    throw e;
  }

  // ── Step F: Auto-repair + Zod on repair output ─────────────────────────────
  const { candidate: candidate2, appliedRules: rules2 } = parseAndAutoRepair(attempt2.rawText);
  const zod2 = FormSchema.safeParse(candidate2);
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
  throw new HttpError(503, "validation_error", "The AI produced an unexpected result. Please try again, or try rephrasing your input.");
}

async function finalize(
  args: GenerateArgs,
  form: GeneratedForm,
  tokens: GeminiAttempt,
): Promise<GenerationOutcome> {
  const { aiRepo, userRepo, user, rowId, generationId } = args;

  await aiRepo.updateSuccess(rowId, {
    outputJson: form,
    inputTokens:  tokens.inputTokens,
    outputTokens: tokens.outputTokens,
  });

  // Quota burns only on successful completion (api-contract.md §4.1).
  if (user.tier === "free") {
    await userRepo.incrementFreeUsed(user.id);
  } else {
    await userRepo.incrementPremiumUsed(user.id);
  }

  return {
    generationId,
    form,
    inputTokens:  tokens.inputTokens,
    outputTokens: tokens.outputTokens,
  };
}
