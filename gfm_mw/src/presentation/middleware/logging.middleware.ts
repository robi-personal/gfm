import { Request, Response, NextFunction } from "express";
import { logger } from "../../infrastructure/logger";

export function loggingMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  req.startTime = Date.now();

  // Child logger bound to this request. Auth middleware (Task 5) re-binds
  // user_id once the token is verified; reads at finish time via req.user.
  req.log = logger.child({ request_id: req.id });

  res.on("finish", () => {
    // req.route is populated by Express after routing completes.
    // Falls back to req.path for 404s and pre-routing errors.
    const route = req.route
      ? `${req.method} ${req.route.path as string}`
      : `${req.method} ${req.path}`;

    req.log.info({
      route,
      user_id:              req.user?.id ?? null,
      status:               res.statusCode,
      latency_ms:           Date.now() - req.startTime,
      gemini_input_tokens:  req.geminiInputTokens  ?? null,
      gemini_output_tokens: req.geminiOutputTokens ?? null,
    }, "request_complete");
  });

  next();
}
