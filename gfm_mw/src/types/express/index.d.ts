import { Logger } from "pino";

declare global {
  namespace Express {
    interface Request {
      // Set by requestIdMiddleware
      id: string;
      startTime: number;

      // Set by loggingMiddleware; updated by authMiddleware to include user_id
      log: Logger;

      // Set by express.json verify callback for HMAC verification on /webhooks/revenuecat
      rawBody?: Buffer;

      // Set by authMiddleware (Task 5); undefined on unauthenticated routes
      user?: {
        id: number;
        googleSub: string;
        email: string;
        tier: "free" | "premium";
      };

      // Set by the /ai/generate handler (Task 14) after a Gemini call
      geminiInputTokens?: number;
      geminiOutputTokens?: number;

      // Set by youtubeMinutesMiddleware — minutes to deduct after successful generation
      videoDurationMinutes?: number;
    }
  }
}
