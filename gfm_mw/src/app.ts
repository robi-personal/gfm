import express, { Application } from "express";

export function createApp(): Application {
  const app = express();

  // Trust exactly one proxy (the Nginx container). In Docker, Nginx is one
  // network hop away — not loopback — so "1" is correct here. This ensures
  // req.ip is the real client IP from X-Forwarded-For. See rate-limiting-abuse.md §4.4.
  app.set("trust proxy", 1);

  // Body parser — 8MB limit covers base64-encoded PDFs up to ~5MB decoded.
  // See rate-limiting-abuse.md §5.2.
  app.use(express.json({ limit: "8mb" }));

  // Liveness probe — no auth, no DB. Used by Docker HEALTHCHECK and load balancers.
  app.get("/ping", (_req, res) => res.json({ ok: true }));

  // Routes are registered here by later tasks:
  //   Task 4  → core middleware (requestId, logging)
  //   Task 5  → auth middleware
  //   Task 6  → kill-switch middleware
  //   Task 7  → rate-limit middleware
  //   Task 9  → GET /user/status
  //   Task 10 → POST /webhooks/revenuecat
  //   Task 14 → POST /ai/generate
  //   Task 15 → GET /health, GET /metrics

  return app;
}
