import express, { Application } from "express";

export function createApp(): Application {
  const app = express();

  // Trust only the local Nginx reverse proxy (loopback).
  // Required for accurate req.ip in rate limiting. See rate-limiting-abuse.md §4.4.
  app.set("trust proxy", "loopback");

  // Body parser — 8MB limit covers base64-encoded PDFs up to ~5MB decoded.
  // See rate-limiting-abuse.md §5.2.
  app.use(express.json({ limit: "8mb" }));

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
