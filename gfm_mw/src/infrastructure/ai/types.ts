import type { Content } from "@google/generative-ai";

// Provider-neutral surface used by ai/generator.ts. Both Gemini and OpenRouter
// providers translate this to/from their own SDK formats internally. The
// `contents` and `responseSchema` fields are typed against the Gemini SDK
// because that is the format the generator + few-shots already emit; the
// OpenRouter provider translates them at its boundary.

export interface AiCallArgs {
  contents: Content[];
  systemInstruction: string;
  responseSchema: unknown;
  deadlineMs?: number;
}

export interface AiResult {
  rawText: string;
  inputTokens: number;
  outputTokens: number;
  finishReason: string;
}

export type AiErrorReason = "ai_unavailable" | "ai_timeout" | "ai_blocked";

export class AiError extends Error {
  reason: AiErrorReason;
  details: Record<string, unknown>;

  constructor(reason: AiErrorReason, details: Record<string, unknown> = {}) {
    super(reason);
    this.name = "AiError";
    this.reason = reason;
    this.details = details;
  }
}

export interface AiProvider {
  readonly name: "gemini" | "openrouter";
  call(args: AiCallArgs): Promise<AiResult>;
  getLastHealth(): { ok: boolean; checkedAt: string };
}
