import { callGemini, getLastGeminiHealth, GeminiError } from "../gemini/gemini-client";
import type { AiCallArgs, AiProvider, AiResult } from "./types";
import { AiError } from "./types";

function geminiErrorToAi(e: GeminiError): AiError {
  const reason =
    e.reason === "gemini_unavailable" ? "ai_unavailable" :
    e.reason === "gemini_timeout"     ? "ai_timeout"     :
    "ai_blocked";
  return new AiError(reason, e.details);
}

export const geminiProvider: AiProvider = {
  name: "gemini",
  async call(args: AiCallArgs): Promise<AiResult> {
    try {
      return await callGemini(args);
    } catch (e) {
      if (e instanceof GeminiError) throw geminiErrorToAi(e);
      throw e;
    }
  },
  getLastHealth() {
    return getLastGeminiHealth();
  },
};
