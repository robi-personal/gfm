import { env } from "../../config/env";
import { geminiProvider } from "./gemini-provider";
import { openrouterProvider } from "./openrouter-provider";
import type { AiProvider } from "./types";

export const aiProvider: AiProvider =
  env.AI_PROVIDER === "openrouter" ? openrouterProvider : geminiProvider;

export { AiError } from "./types";
export type { AiCallArgs, AiResult, AiErrorReason, AiProvider } from "./types";
