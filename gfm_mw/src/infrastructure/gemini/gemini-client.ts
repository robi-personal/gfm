import {
  GoogleGenerativeAI,
  Content,
  FinishReason,
  GoogleGenerativeAIFetchError,
  ResponseSchema,
  GenerativeModel,
} from "@google/generative-ai";
import { env } from "../../config/env";
import { logger } from "../logger";

const MODEL = "gemini-2.0-flash";
const DEFAULT_DEADLINE_MS = 30_000;
const RETRY_BACKOFF_MS = 500;

export class GeminiError extends Error {
  reason: "gemini_unavailable" | "gemini_timeout" | "gemini_blocked";
  details: Record<string, unknown>;

  constructor(
    reason: "gemini_unavailable" | "gemini_timeout" | "gemini_blocked",
    details: Record<string, unknown> = {},
  ) {
    super(reason);
    this.name = "GeminiError";
    this.reason = reason;
    this.details = details;
  }
}

export interface CallGeminiArgs {
  contents: Content[];
  systemInstruction: string;
  responseSchema: unknown;
  deadlineMs?: number;
}

export interface GeminiResult {
  rawText: string;
  inputTokens: number;
  outputTokens: number;
  finishReason: string;
}

const genAI = new GoogleGenerativeAI(env.GEMINI_API_KEY);

function isAbortError(err: unknown): boolean {
  if (!(err instanceof Error)) return false;
  return err.name === "AbortError" || (err as NodeJS.ErrnoException).code === "ABORT_ERR";
}

function is4xx(err: unknown): boolean {
  return (
    err instanceof GoogleGenerativeAIFetchError &&
    typeof err.status === "number" &&
    err.status >= 400 &&
    err.status < 500
  );
}

function is5xx(err: unknown): boolean {
  return (
    err instanceof GoogleGenerativeAIFetchError &&
    typeof err.status === "number" &&
    err.status >= 500
  );
}

function abortSleep(ms: number, signal: AbortSignal): Promise<void> {
  return new Promise<void>((resolve, reject) => {
    if (signal.aborted) {
      reject(new GeminiError("gemini_timeout"));
      return;
    }
    const t = setTimeout(resolve, ms);
    signal.addEventListener(
      "abort",
      () => {
        clearTimeout(t);
        reject(new GeminiError("gemini_timeout"));
      },
      { once: true },
    );
  });
}

async function doAttempt(
  model: GenerativeModel,
  contents: Content[],
  signal: AbortSignal,
  attemptNumber: number,
): Promise<GeminiResult> {
  const startMs = Date.now();
  logger.info({ attemptNumber }, "gemini_attempt_start");

  let response;
  try {
    const result = await model.generateContent({ contents }, { signal });
    response = result.response;
  } catch (err) {
    const latencyMs = Date.now() - startMs;

    if (isAbortError(err) || signal.aborted) {
      logger.info({ attemptNumber, latencyMs, outcome: "timeout" }, "gemini_attempt_end");
      throw new GeminiError("gemini_timeout");
    }
    if (is4xx(err)) {
      const status = (err as GoogleGenerativeAIFetchError).status;
      logger.info({ attemptNumber, latencyMs, outcome: "4xx", status }, "gemini_attempt_end");
      throw new GeminiError("gemini_unavailable");
    }
    if (is5xx(err)) {
      const status = (err as GoogleGenerativeAIFetchError).status;
      logger.info({ attemptNumber, latencyMs, outcome: "5xx", status }, "gemini_attempt_end");
      // Re-throw so caller can decide whether to retry
      throw err;
    }

    logger.info({ attemptNumber, latencyMs, outcome: "error", err }, "gemini_attempt_end");
    throw new GeminiError("gemini_unavailable");
  }

  const latencyMs = Date.now() - startMs;
  const usage = response.usageMetadata;
  const inputTokens = usage?.promptTokenCount ?? 0;
  const outputTokens = usage?.candidatesTokenCount ?? 0;
  const candidate = response.candidates?.[0];
  const finishReason: string = candidate?.finishReason ?? FinishReason.FINISH_REASON_UNSPECIFIED;

  if (finishReason === FinishReason.SAFETY) {
    logger.info(
      { attemptNumber, latencyMs, finishReason, outcome: "blocked", inputTokens, outputTokens },
      "gemini_attempt_end",
    );
    throw new GeminiError("gemini_blocked", { finishReason, inputTokens, outputTokens });
  }

  let rawText: string;
  try {
    rawText = response.text();
  } catch {
    logger.info(
      { attemptNumber, latencyMs, finishReason, outcome: "blocked_no_text", inputTokens, outputTokens },
      "gemini_attempt_end",
    );
    throw new GeminiError("gemini_blocked", { finishReason, inputTokens, outputTokens });
  }

  if (!rawText) {
    logger.info(
      { attemptNumber, latencyMs, finishReason, outcome: "blocked_empty", inputTokens, outputTokens },
      "gemini_attempt_end",
    );
    throw new GeminiError("gemini_blocked", { finishReason, inputTokens, outputTokens });
  }

  logger.info(
    { attemptNumber, latencyMs, finishReason, outcome: "success", inputTokens, outputTokens },
    "gemini_attempt_end",
  );
  return { rawText, inputTokens, outputTokens, finishReason };
}

export async function callGemini(args: CallGeminiArgs): Promise<GeminiResult> {
  const { contents, systemInstruction, responseSchema, deadlineMs = DEFAULT_DEADLINE_MS } = args;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), deadlineMs);

  const model = genAI.getGenerativeModel({
    model: MODEL,
    systemInstruction,
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: responseSchema as ResponseSchema,
      temperature: 0.4,
      maxOutputTokens: 4096,
      candidateCount: 1,
    },
  });

  try {
    // Attempt 1
    try {
      return await doAttempt(model, contents, controller.signal, 1);
    } catch (err) {
      // GeminiError (timeout, 4xx, blocked, unknown) — propagate immediately
      if (err instanceof GeminiError) throw err;

      // Reached here only for 5xx from doAttempt. Check deadline before retry.
      if (controller.signal.aborted) throw new GeminiError("gemini_timeout");

      await abortSleep(RETRY_BACKOFF_MS, controller.signal);
    }

    // Attempt 2
    try {
      return await doAttempt(model, contents, controller.signal, 2);
    } catch (err) {
      if (err instanceof GeminiError) throw err;
      // 5xx on attempt 2 — give up
      throw new GeminiError("gemini_unavailable");
    }
  } finally {
    clearTimeout(timer);
  }
}
