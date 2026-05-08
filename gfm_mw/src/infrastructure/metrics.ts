import { Counter, Gauge, Histogram, Registry, collectDefaultMetrics } from "prom-client";
import { env } from "../config/env";

export const register = new Registry();

collectDefaultMetrics({ register });

// ── HTTP layer ──────────────────────────────────────────────────────────────

export const httpRequestDurationMs = new Histogram({
  name: "http_request_duration_ms",
  help: "HTTP request latency in milliseconds",
  labelNames: ["route", "method", "status_class"] as const,
  buckets: [50, 100, 250, 500, 1000, 2500, 5000, 10000, 30000],
  registers: [register],
});

export const httpRequestsTotal = new Counter({
  name: "http_requests_total",
  help: "Total HTTP requests",
  labelNames: ["route", "method", "status"] as const,
  registers: [register],
});

// ── Gemini ──────────────────────────────────────────────────────────────────

export const geminiRequestsTotal = new Counter({
  name: "gemini_requests_total",
  help: "Total calls made to Gemini (including retries)",
  labelNames: ["outcome"] as const,
  registers: [register],
});

export const geminiInputTokensTotal = new Counter({
  name: "gemini_input_tokens_total",
  help: "Total input tokens sent to Gemini",
  registers: [register],
});

export const geminiOutputTokensTotal = new Counter({
  name: "gemini_output_tokens_total",
  help: "Total output tokens received from Gemini",
  registers: [register],
});

export const geminiSpendUsdToday = new Gauge({
  name: "gemini_spend_usd_today",
  help: "Estimated Gemini spend today (UTC day), in USD",
  registers: [register],
});

// Set at boot from env; used in §5.4 alert expressions.
export const geminiSpendCapUsd = new Gauge({
  name: "gemini_spend_cap_usd",
  help: "MAX_DAILY_GEMINI_SPEND_USD hard cap, in USD",
  registers: [register],
});
geminiSpendCapUsd.set(env.MAX_DAILY_GEMINI_SPEND_USD);

// ── Quota ───────────────────────────────────────────────────────────────────

export const quotaExceededTotal = new Counter({
  name: "quota_exceeded_total",
  help: "Times a user hit their generation quota",
  labelNames: ["tier"] as const,
  registers: [register],
});

// ── Rate limiting + kill switches ───────────────────────────────────────────

export const rateLimitExceededTotal = new Counter({
  name: "rate_limit_exceeded_total",
  help: "Times a rate limit bucket was exceeded",
  labelNames: ["scope", "route"] as const,
  registers: [register],
});

export const killSwitchTrippedTotal = new Counter({
  name: "kill_switch_tripped_total",
  help: "Times a kill switch rejected a request",
  labelNames: ["which"] as const,
  registers: [register],
});

export const costBreakerTrippedTotal = new Counter({
  name: "cost_breaker_tripped_total",
  help: "Times a cost circuit breaker rejected a request",
  labelNames: ["scope"] as const,
  registers: [register],
});

// ── URL fetcher ─────────────────────────────────────────────────────────────

export const urlFetchBlockedTotal = new Counter({
  name: "url_fetch_blocked_total",
  help: "Times a URL fetch was blocked by a safety check",
  labelNames: ["reason"] as const,
  registers: [register],
});

// ── RevenueCat webhooks ─────────────────────────────────────────────────────

export const rcWebhookTotal = new Counter({
  name: "rc_webhook_total",
  help: "RevenueCat webhook events received",
  labelNames: ["event_type", "outcome"] as const,
  registers: [register],
});

export const rcWebhookLagMs = new Histogram({
  name: "rc_webhook_lag_ms",
  help: "Time between RC event timestamp and our processing time (ms)",
  buckets: [1_000, 5_000, 30_000, 60_000, 300_000, 1_800_000, 3_600_000],
  registers: [register],
});

// ── Dependency health ───────────────────────────────────────────────────────

export const healthDegraded = new Gauge({
  name: "health_dep_degraded",
  help: "1 if a dependency is unhealthy, 0 if healthy",
  labelNames: ["dep"] as const,
  registers: [register],
});
