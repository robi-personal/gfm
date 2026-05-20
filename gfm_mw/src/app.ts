import express, { Application, Request, Response, NextFunction } from "express";
import * as Sentry from "@sentry/node";
import { join } from "path";
import { requestIdMiddleware } from "./presentation/middleware/request-id.middleware";
import { loggingMiddleware } from "./presentation/middleware/logging.middleware";
import { errorMiddleware } from "./presentation/middleware/error.middleware";
import { aiGenerationDisabledMiddleware } from "./presentation/middleware/kill-switch.middleware";
import {
  aiGlobalLimitMiddleware,
  aiIpLimitMiddleware,
  defaultIpLimitMiddleware,
} from "./presentation/middleware/rate-limit.middleware";
import { userRouter } from "./presentation/routes/user.routes";
import { webhookRouter } from "./presentation/routes/webhook.routes";
import { aiRouter } from "./presentation/routes/ai.routes";
import { healthRouter } from "./presentation/routes/health.routes";
import { adminRouter } from "./presentation/routes/admin.routes";
import { devicesRouter } from "./presentation/routes/devices.routes";
import { watchesRouter } from "./presentation/routes/watches.routes";

export function createApp(): Application {
  const app = express();

  // Trust exactly one proxy (the Nginx container). In Docker, Nginx is one
  // network hop away — not loopback — so "1" is correct here. This ensures
  // req.ip is the real client IP from X-Forwarded-For. See rate-limiting-abuse.md §4.4.
  app.set("trust proxy", 1);

  // ── Core middleware ────────────────────────────────────────────────────────
  app.use(requestIdMiddleware);  // must be first — everything else needs req.id
  app.use(loggingMiddleware);    // attaches req.log, fires request_complete on finish

  // Body parser — 8MB limit covers base64-encoded PDFs up to ~5MB decoded.
  // verify captures raw bytes before parsing for HMAC verification on /webhooks/revenuecat.
  // See rate-limiting-abuse.md §5.2 and revenuecat-webhook-map.md §2.1.
  app.use(express.json({
    limit: "8mb",
    verify: (req: Request, _res: Response, buf: Buffer) => {
      req.rawBody = buf;
    },
  }));

  // Liveness probe — no auth, no DB. Used by Docker HEALTHCHECK and load balancers.
  app.get("/ping", (_req, res) => res.json({ ok: true }));

  // ── Kill switch + coarse rate limits on /ai/* (before auth) ───────────────
  // Order per rate-limiting-abuse.md §12: kill switch → global RL → per-IP RL → auth.
  app.use("/ai", aiGenerationDisabledMiddleware);
  app.use("/ai", aiGlobalLimitMiddleware);
  app.use("/ai", aiIpLimitMiddleware);

  // ── Routes ────────────────────────────────────────────────────────────────
  app.use("/ai",       aiRouter);
  app.use("/user",     userRouter);
  app.use("/devices",  devicesRouter);
  app.use("/watches",  watchesRouter);
  app.use("/webhooks", webhookRouter);
  // Static admin UI served before API routes — index.html and assets are public.
  // API routes under /admin/* are protected by adminAuthMiddleware inside adminRouter.
  const adminDist = join(__dirname, "../admin-dist");
  app.use("/admin", express.static(adminDist));
  app.use("/admin",    adminRouter);
  app.get("/admin/*", (_req, res) => res.sendFile(join(adminDist, "index.html")));
  app.use("/",         healthRouter);   // GET /health, GET /metrics

  // ── 404 + catch-all rate limit ────────────────────────────────────────────
  // Default per-IP limiter throttles unrecognised-path probing before sending 404.
  app.all("*", defaultIpLimitMiddleware, (_req: Request, res: Response) => {
    res.status(404).json({ code: "not_found", message: "Route not found." });
  });

  // ── Sentry error handler (must be before custom error middleware) ─────────
  Sentry.setupExpressErrorHandler(app);

  // ── Error handler (must be last) ──────────────────────────────────────────
  app.use(errorMiddleware);

  return app;
}
