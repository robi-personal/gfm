import { Request, Response, NextFunction } from "express";
import { logger } from "../../infrastructure/logger";
import { httpRequestDurationMs, httpRequestsTotal } from "../../infrastructure/metrics";

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
    const latencyMs = Date.now() - req.startTime;
    const route = req.route
      ? `${req.method} ${req.route.path as string}`
      : `${req.method} ${req.path}`;

    req.log.info({
      route,
      user_id:              req.user?.id ?? null,
      status:               res.statusCode,
      latency_ms:           latencyMs,
      gemini_input_tokens:  req.geminiInputTokens  ?? null,
      gemini_output_tokens: req.geminiOutputTokens ?? null,
    }, "request_complete");

    const statusClass =
      res.statusCode < 300 ? "2xx" :
      res.statusCode < 500 ? "4xx" : "5xx";
    const statusStr = String(res.statusCode);

    httpRequestDurationMs.observe({ route, method: req.method, status_class: statusClass }, latencyMs);
    httpRequestsTotal.inc({ route, method: req.method, status: statusStr });
  });

  next();
}
