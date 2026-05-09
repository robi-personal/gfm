import type { Content, Part } from "@google/generative-ai";
import { env } from "../../config/env";
import { logger } from "../logger";
import {
  geminiRequestsTotal,
  geminiInputTokensTotal,
  geminiOutputTokensTotal,
} from "../metrics";
import { AiError } from "./types";
import type { AiCallArgs, AiProvider, AiResult } from "./types";

const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";
const DEFAULT_DEADLINE_MS = 30_000;

interface OrMessage {
  role: "system" | "user" | "assistant";
  content: string;
}

interface OrResponse {
  choices?: { message?: { content?: string }; finish_reason?: string }[];
  usage?: { prompt_tokens?: number; completion_tokens?: number };
  error?: { message?: string; code?: number | string };
}

let lastHealth = { ok: true, checkedAt: new Date().toISOString() };

// OpenRouter speaks the OpenAI chat-completions API. PDFs, inline images, and
// YouTube fileData parts that Gemini accepts natively cannot be passed through
// most OR models, so we extract text parts and drop binaries with a warning.
// Practical implication: only inputType=text and inputType=urls work end-to-end
// on OpenRouter today; pdf/book/youtube will degrade to "based on the
// description" without the actual file.
function partsToText(parts: Part[]): { text: string; droppedBinary: boolean } {
  let droppedBinary = false;
  const pieces: string[] = [];
  for (const p of parts) {
    if ("text" in p && typeof p.text === "string") {
      pieces.push(p.text);
    } else if ("inlineData" in p && p.inlineData) {
      droppedBinary = true;
      pieces.push(`[attached ${p.inlineData.mimeType} omitted — provider does not support binary input]`);
    } else if ("fileData" in p && p.fileData) {
      droppedBinary = true;
      pieces.push(`[attached ${p.fileData.mimeType} at ${p.fileData.fileUri} omitted — provider does not support file URIs]`);
    }
  }
  return { text: pieces.join("\n").trim(), droppedBinary };
}

function translateContents(
  contents: Content[],
  systemInstruction: string,
): { messages: OrMessage[]; droppedBinary: boolean } {
  const messages: OrMessage[] = [{ role: "system", content: systemInstruction }];
  let droppedBinary = false;
  for (const c of contents) {
    const { text, droppedBinary: dropped } = partsToText(c.parts);
    if (dropped) droppedBinary = true;
    if (!text) continue;
    const role: OrMessage["role"] = c.role === "model" ? "assistant" : "user";
    messages.push({ role, content: text });
  }
  return { messages, droppedBinary };
}

function recordSuccess(inputTokens: number, outputTokens: number): void {
  geminiRequestsTotal.inc({ outcome: "success" });
  geminiInputTokensTotal.inc(inputTokens);
  geminiOutputTokensTotal.inc(outputTokens);
  lastHealth = { ok: true, checkedAt: new Date().toISOString() };
}

function recordFailure(outcome: "gemini_error" | "gemini_timeout"): void {
  geminiRequestsTotal.inc({ outcome });
  lastHealth = { ok: false, checkedAt: new Date().toISOString() };
}

export const openrouterProvider: AiProvider = {
  name: "openrouter",
  async call(args: AiCallArgs): Promise<AiResult> {
    const { contents, systemInstruction, deadlineMs = DEFAULT_DEADLINE_MS } = args;

    if (!env.OPENROUTER_API_KEY) {
      // Should be caught by env refine at startup, but guard at call time too.
      throw new AiError("ai_unavailable", { reason: "missing_openrouter_api_key" });
    }

    const { messages, droppedBinary } = translateContents(contents, systemInstruction);
    if (droppedBinary) {
      logger.warn(
        { provider: "openrouter", model: env.OPENROUTER_MODEL },
        "openrouter_binary_input_dropped",
      );
    }

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), deadlineMs);
    const startMs = Date.now();

    logger.info({ provider: "openrouter", model: env.OPENROUTER_MODEL }, "openrouter_attempt_start");

    try {
      const res = await fetch(OPENROUTER_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${env.OPENROUTER_API_KEY}`,
          // OpenRouter recommends these for analytics + free-tier eligibility.
          "HTTP-Referer": "https://gfm.app",
          "X-Title": "GFM",
        },
        body: JSON.stringify({
          model: env.OPENROUTER_MODEL,
          messages,
          temperature: 0.4,
          max_tokens: 4096,
          response_format: { type: "json_object" },
        }),
        signal: controller.signal,
      });

      const latencyMs = Date.now() - startMs;

      if (!res.ok) {
        const bodyText = await res.text().catch(() => "");
        logger.info(
          {
            provider: "openrouter",
            latencyMs,
            outcome: res.status >= 500 ? "5xx" : "4xx",
            status: res.status,
            body: bodyText.slice(0, 500),
          },
          "openrouter_attempt_end",
        );
        recordFailure("gemini_error");
        throw new AiError("ai_unavailable", {
          status: res.status,
          body: bodyText.slice(0, 500),
        });
      }

      const data = (await res.json()) as OrResponse;

      if (data.error) {
        logger.info(
          { provider: "openrouter", latencyMs, outcome: "api_error", error: data.error },
          "openrouter_attempt_end",
        );
        recordFailure("gemini_error");
        throw new AiError("ai_unavailable", { apiError: data.error });
      }

      const choice = data.choices?.[0];
      const rawText = choice?.message?.content ?? "";
      const inputTokens = data.usage?.prompt_tokens ?? 0;
      const outputTokens = data.usage?.completion_tokens ?? 0;
      const finishReason = choice?.finish_reason ?? "stop";

      if (!rawText) {
        logger.info(
          { provider: "openrouter", latencyMs, outcome: "empty", finishReason, inputTokens, outputTokens },
          "openrouter_attempt_end",
        );
        recordFailure("gemini_error");
        throw new AiError("ai_blocked", { finishReason, inputTokens, outputTokens });
      }

      logger.info(
        { provider: "openrouter", latencyMs, outcome: "success", finishReason, inputTokens, outputTokens },
        "openrouter_attempt_end",
      );
      recordSuccess(inputTokens, outputTokens);
      return { rawText, inputTokens, outputTokens, finishReason };
    } catch (err) {
      if (err instanceof AiError) throw err;

      const aborted =
        controller.signal.aborted ||
        (err instanceof Error &&
          (err.name === "AbortError" || (err as NodeJS.ErrnoException).code === "ABORT_ERR"));
      if (aborted) {
        const latencyMs = Date.now() - startMs;
        logger.info(
          { provider: "openrouter", latencyMs, outcome: "timeout" },
          "openrouter_attempt_end",
        );
        recordFailure("gemini_timeout");
        throw new AiError("ai_timeout");
      }

      logger.error({ err, provider: "openrouter" }, "openrouter_unexpected_error");
      recordFailure("gemini_error");
      throw new AiError("ai_unavailable");
    } finally {
      clearTimeout(timer);
    }
  },
  getLastHealth() {
    return lastHealth;
  },
};
