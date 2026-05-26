# Observability — Structured Logging, Metrics & Alerting

**Owner:** Backend (`gfm_mw` — Node + Express on Hostinger VPS)
**Depends on:** `docs/api-contract.md` (endpoints, error codes), `docs/rate-limiting-abuse.md`, `docs/revenuecat-webhook-map.md`
**Source of truth:** This document for all observability contracts. Signal names and field names are stable — change requires a version bump here.

Implementation files: `gfm_mw/src/infrastructure/logger.ts`, `gfm_mw/src/infrastructure/metrics.ts`, `gfm_mw/src/presentation/middleware/logging.middleware.ts`, `gfm_mw/src/presentation/routes/health.routes.ts`.

---

## 1. Stack Choice

| Concern | Tool | Why |
|---|---|---|
| Structured logging | **`pino`** | Fastest Node JSON logger; natively compatible with PM2 log rotation; no agent required |
| Metrics exposition | **`prom-client`** | De-facto Prometheus client for Node; exposes `/metrics` in the standard scrape format |
| Metrics storage + query | **Prometheus** (same VPS) | Single-binary, low RAM, trivial to run alongside the app process |
| Dashboards | **Grafana** (same VPS or Grafana Cloud free tier) | Native Prometheus datasource; free |
| Error tracking | **Sentry** (cloud, free tier) | Captures stack traces, tags by user/request, groups noise; no infra to run |

**Why not a hosted log aggregator (Datadog, Logtail)?** For MVP on a single VPS with PM2, `pino` writes newline-delimited JSON to stdout; PM2 captures that to `/root/.pm2/logs/`. This is sufficient until traffic warrants a log shipper. The structured fields below are designed so a shipper can be added later with zero schema change.

---

## 2. Structured Logging

### 2.1 Log format

Every log line is a single JSON object on stdout. `pino` handles serialization.

```typescript
// lib/logger.ts
import pino from "pino";

export const logger = pino({
  level: process.env.LOG_LEVEL ?? "info",
  base: {
    service: "gfm-api",
    version:  process.env.npm_package_version,
    env:      process.env.NODE_ENV,
  },
  timestamp: pino.stdTimeFunctions.isoTime,
});
```

All per-request logging uses a child logger with the request context bound once:

```typescript
req.log = logger.child({
  request_id: req.id,         // from requestId() middleware
  route:      req.routeKey,   // normalized pattern, e.g. "POST /ai/generate"
  user_id:    req.user?.id ?? null,
});
```

### 2.2 Required fields — every request

These fields appear on the **response log line** emitted by the logging middleware when the response is sent:

| Field | Type | Source | Notes |
|---|---|---|---|
| `request_id` | string | `X-Request-Id` header or generated UUID | Echoed in response header |
| `user_id` | integer \| null | `req.user.id` after auth; null if unauthenticated | `users.id`, not `google_sub` |
| `route` | string | `req.method + " " + req.route.path` | Normalized: `"POST /ai/generate"`, not the full URL |
| `status` | integer | `res.statusCode` | HTTP response status |
| `latency_ms` | number | `Date.now() - req.startTime` | Wall-clock ms from first byte of request to last byte of response |
| `gemini_input_tokens` | integer \| null | From Gemini response, stored on `req` | null for all non-AI routes and AI errors that never reached Gemini |
| `gemini_output_tokens` | integer \| null | Same | Same |

```typescript
// Logging middleware (runs on response finish)
app.use((req, res, next) => {
  req.startTime = Date.now();
  res.on("finish", () => {
    req.log.info({
      status:               res.statusCode,
      latency_ms:           Date.now() - req.startTime,
      gemini_input_tokens:  req.geminiInputTokens  ?? null,
      gemini_output_tokens: req.geminiOutputTokens ?? null,
    }, "request_complete");
  });
  next();
});
```

### 2.3 Route-specific additional fields

These are logged alongside the required fields where applicable.

#### `POST /ai/generate`

| Field | Type | When present | Notes |
|---|---|---|---|
| `input_type` | string | always | `"text"` \| `"pdf"` \| `"youtube"` \| `"urls"` \| `"book"` |
| `idempotency_key` | string | always | Client-supplied UUID |
| `generation_id` | string \| null | On 200 success | Server-generated UUID |
| `quota_tier` | string | After auth | `"free"` \| `"premium"` |
| `quota_used_after` | integer \| null | On 200 success | `ai_free_used` or `ai_premium_used` after increment |
| `cache_hit` | boolean | always | `true` if idempotency replay; `false` if fresh generation |
| `gemini_attempts` | integer | After Gemini call(s) | `1` or `2` (after retry) |
| `validation_repair` | boolean | When Zod validation ran | `true` if the repair turn was used |
| `error_code` | string \| null | On non-200 | The `code` from the error response body |

#### `POST /webhooks/revenuecat`

| Field | Type | Notes |
|---|---|---|
| `event_id` | string | RC event.id |
| `event_type` | string | e.g. `"RENEWAL"` |
| `is_duplicate` | boolean | `true` if deduped |
| `is_sandbox` | boolean | `true` if `environment = "SANDBOX"` |
| `rc_event_at_ms` | integer | `event.purchased_at_ms` — used to compute webhook lag |
| `webhook_lag_ms` | integer | `Date.now() - event.purchased_at_ms` |

#### `GET /user/status`

No additional fields beyond the standard set. This route does one DB read and returns; extra context is not useful.

### 2.4 Log levels

| Level | When to use |
|---|---|
| `error` | Unhandled exception; Gemini 5xx after retry; DB connection failure; HMAC mismatch (security event) |
| `warn` | Rate limit exceeded; kill switch tripped; cost circuit breaker tripped; unknown RC user; sandbox event in prod; unknown RC event type; SSRF attempt blocked |
| `info` | Request completed (all statuses); RC event processed; idempotency cache hit; generation success/failure |
| `debug` | Internal decision points (idempotency state machine steps, Zod validation details). **Not emitted in production.** |

`LOG_LEVEL=info` in production. `LOG_LEVEL=debug` in development only.

### 2.5 What NOT to log

- `Authorization` header values (tokens, HMAC secrets)
- `fileBase64` / raw PDF bytes
- Full `prompt` text (may contain PII). Log `prompt_length_chars` instead.
- `google_sub` of the user (use `user_id` integer). `google_sub` is a stable identifier; `user_id` is internal.
- Full RC `raw_payload` in the log line — it's in the DB. Log `event_id` + `event_type` only.

---

## 3. Metrics

All metrics use `prom-client` with the Prometheus naming convention (`snake_case`, unit suffix).

### 3.1 HTTP layer

```typescript
// Histogram: latency per route+method+status
const httpRequestDurationMs = new Histogram({
  name: "http_request_duration_ms",
  help: "HTTP request latency in milliseconds",
  labelNames: ["route", "method", "status_class"],
  // status_class: "2xx" | "4xx" | "5xx" — avoids high cardinality from exact codes
  buckets: [50, 100, 250, 500, 1000, 2500, 5000, 10000, 30000],
});

// Counter: total requests
const httpRequestsTotal = new Counter({
  name: "http_requests_total",
  help: "Total HTTP requests",
  labelNames: ["route", "method", "status"],
});
```

Deriving **requests/min**: `rate(http_requests_total[1m])` in Prometheus.

Deriving **p50/p95/p99**: `histogram_quantile(0.95, rate(http_request_duration_ms_bucket[5m]))`.

### 3.2 Gemini

```typescript
// Counter: Gemini call outcomes
const geminiRequestsTotal = new Counter({
  name: "gemini_requests_total",
  help: "Total calls made to Gemini (including retries)",
  labelNames: ["outcome"],
  // outcome: "success" | "gemini_error" | "gemini_timeout" | "validation_error" | "fallback_detected"
});

// Counter: tokens consumed (for cost tracking)
const geminiInputTokensTotal = new Counter({
  name: "gemini_input_tokens_total",
  help: "Total input tokens sent to Gemini",
});
const geminiOutputTokensTotal = new Counter({
  name: "gemini_output_tokens_total",
  help: "Total output tokens received from Gemini",
});

// Gauge: rolling daily USD spend (same value as the in-memory cache in rate-limiting-abuse.md §8.2)
const geminiSpendUsdToday = new Gauge({
  name: "gemini_spend_usd_today",
  help: "Estimated Gemini spend today (UTC day), in USD",
});
```

Deriving **Gemini error rate**: `rate(gemini_requests_total{outcome=~"gemini_error|gemini_timeout|validation_error"}[5m]) / rate(gemini_requests_total[5m])`.

### 3.3 Quota

```typescript
const quotaExceededTotal = new Counter({
  name: "quota_exceeded_total",
  help: "Times a user hit their generation quota",
  labelNames: ["tier"],   // "free" | "premium"
});
```

Deriving **quota-exceeded rate**: `rate(quota_exceeded_total[5m])`.

### 3.4 Rate limiting and kill switches

Required by `rate-limiting-abuse.md §13`:

```typescript
const rateLimitExceededTotal = new Counter({
  name: "rate_limit_exceeded_total",
  help: "Times a rate limit bucket was exceeded",
  labelNames: ["scope", "route"],
  // scope: "global" | "per-ip" | "per-user-hourly" | "per-user-daily"
});

const killSwitchTrippedTotal = new Counter({
  name: "kill_switch_tripped_total",
  help: "Times a kill switch rejected a request",
  labelNames: ["which"],
  // which: "ai_generation_disabled" | "daily_budget_exceeded" | "user_blocked"
});

const costBreakerTrippedTotal = new Counter({
  name: "cost_breaker_tripped_total",
  help: "Times a cost circuit breaker rejected a request",
  labelNames: ["scope"],
  // scope: "per-user" | "global"
});
```

### 3.5 URL fetcher (SSRF defense)

Required by `rate-limiting-abuse.md §13`:

```typescript
const urlFetchBlockedTotal = new Counter({
  name: "url_fetch_blocked_total",
  help: "Times a URL fetch was blocked by a safety check",
  labelNames: ["reason"],
  // reason: "private_ip" | "too_many_redirects" | "unsupported_content_type"
  //         | "body_too_large" | "timeout" | "dns_failure"
});
// ssrf.blocked is url_fetch_blocked_total{reason="private_ip"} — no separate metric needed.
// Alert rule queries this label directly (see §5).
```

### 3.6 RevenueCat webhooks

```typescript
const rcWebhookTotal = new Counter({
  name: "rc_webhook_total",
  help: "RevenueCat webhook events received",
  labelNames: ["event_type", "outcome"],
  // outcome: "processed" | "duplicate" | "unknown_user" | "sandbox_skipped" | "error"
});

const rcWebhookLagMs = new Histogram({
  name: "rc_webhook_lag_ms",
  help: "Time between RC event timestamp and our processing time (ms)",
  // Bucket at subscription-relevance boundaries
  buckets: [1_000, 5_000, 30_000, 60_000, 300_000, 1_800_000, 3_600_000],
  // 1s, 5s, 30s, 1m, 5m, 30m, 1h
});
```

Deriving **RC webhook lag**: `histogram_quantile(0.95, rate(rc_webhook_lag_ms_bucket[1h]))`.

### 3.7 `/health` dependency state

```typescript
const healthDegraded = new Gauge({
  name: "health_dep_degraded",
  help: "1 if a dependency is unhealthy, 0 if healthy",
  labelNames: ["dep"],
  // dep: "postgres" | "redis" | "gemini"
});
```

Set to `1` when the `/health` computation detects a failed dep; set to `0` when it recovers. Required by `rate-limiting-abuse.md §13` (`health.degraded{dep}` event).

### 3.8 `/metrics` endpoint

```typescript
app.get("/metrics", auth.healthToken, async (_req, res) => {
  res.set("Content-Type", register.contentType);
  res.end(await register.metrics());
});
```

Same `HEALTH_TOKEN` auth as `/health` (rate-limiting-abuse.md §10.4). Prometheus scrapes this endpoint; Grafana queries Prometheus.

---

## 4. Error Tracking (Sentry)

### 4.1 Initialization

```typescript
import * as Sentry from "@sentry/node";

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,       // "production" | "staging"
  release: process.env.npm_package_version,
  tracesSampleRate: 0.05,                  // 5% of requests for performance tracing; cost-bounded
  integrations: [
    Sentry.prismaIntegration(),            // swap for pg integration if using pg directly
  ],
});

// RequestHandler before routes; ErrorHandler after routes
app.use(Sentry.Handlers.requestHandler());
// ... routes ...
app.use(Sentry.Handlers.errorHandler());
```

### 4.2 User context

Set in the auth middleware, immediately after token verification:

```typescript
Sentry.setUser({ id: String(req.user.id) });
```

This tags every subsequent error in the request with `user_id`. The `id` field maps to `users.id` (integer). Do not set `email` or `username` — unnecessary PII exposure.

### 4.3 What Sentry captures

| Scenario | Captured? | Level | Notes |
|---|---|---|---|
| Unhandled exception in any route | Yes | error | Via `errorHandler` middleware |
| Gemini 5xx after retry (`gemini_unavailable`) | Yes | warning | Manual `Sentry.captureException` with `req.log` context |
| Zod validation failure on Gemini output | Yes | warning | Includes both raw Gemini output attempts in `extra` |
| DB connection failure | Yes | error | Via unhandled rejection |
| HMAC mismatch on RC webhook | Yes | warning | Security event; log + Sentry |
| 400 `invalid_input` (bad client request) | No | — | Expected; high volume; not actionable |
| 429 `quota_exceeded` / `rate_limited` | No | — | Expected; not actionable |
| 401 / 403 | No | — | Expected |
| 503 `service_disabled` / `daily_budget_exceeded` | No | — | Intentional kill-switch behavior |

### 4.4 Additional context on AI errors

```typescript
Sentry.withScope((scope) => {
  scope.setTag("route",        "POST /ai/generate");
  scope.setTag("input_type",   req.body.inputType);
  scope.setTag("quota_tier",   req.user.tier);
  scope.setExtra("generation_id",     req.generationId);
  scope.setExtra("gemini_attempts",   req.geminiAttempts);
  scope.setExtra("validation_error",  zodError?.message);
  Sentry.captureException(err);
});
```

---

## 5. Alert Thresholds

Alerts are defined as Prometheus alerting rules (evaluated by the Prometheus server). They fire to a notification channel — Slack webhook or PagerDuty, configured in `alertmanager.yml`.

### 5.1 Availability

```yaml
- alert: HighErrorRate
  expr: |
    rate(http_requests_total{status=~"5.."}[5m])
    / rate(http_requests_total[5m]) > 0.10
  for: 5m
  severity: page
  annotations:
    summary: "5xx rate above 10% for 5 minutes"

- alert: ServiceDown
  expr: up{job="gfm-api"} == 0
  for: 1m
  severity: page
  annotations:
    summary: "gfm-api process not reachable by Prometheus"
```

### 5.2 Latency

```yaml
- alert: HighP99Latency
  expr: |
    histogram_quantile(0.99,
      rate(http_request_duration_ms_bucket{route="POST /ai/generate"}[5m])
    ) > 25000
  for: 5m
  severity: warn
  annotations:
    summary: "p99 latency on /ai/generate above 25s (approaching 30s timeout)"
```

### 5.3 Gemini

```yaml
- alert: GeminiErrorRateWarn
  expr: |
    rate(gemini_requests_total{outcome=~"gemini_error|gemini_timeout|validation_error"}[5m])
    / rate(gemini_requests_total[5m]) > 0.05
  for: 5m
  severity: warn
  annotations:
    summary: "Gemini error rate above 5% for 5 minutes"

- alert: GeminiErrorRatePage
  expr: |
    rate(gemini_requests_total{outcome=~"gemini_error|gemini_timeout|validation_error"}[5m])
    / rate(gemini_requests_total[5m]) > 0.20
  for: 5m
  severity: page
  annotations:
    summary: "Gemini error rate above 20% — likely Gemini outage"
```

### 5.4 Cost (from `rate-limiting-abuse.md §13`)

```yaml
- alert: GeminiSpendWarn
  expr: gemini_spend_usd_today > (0.70 * on() group_left() gemini_spend_cap_usd)
  for: 0m    # fire immediately — cost events are not transient
  severity: warn
  annotations:
    summary: "Daily Gemini spend above 70% of cap"

- alert: GeminiSpendPage
  expr: gemini_spend_usd_today > (0.90 * on() group_left() gemini_spend_cap_usd)
  for: 0m
  severity: page
  annotations:
    summary: "Daily Gemini spend above 90% of cap — kill switch may be imminent"
```

`gemini_spend_cap_usd` is a Gauge set at process boot from `MAX_DAILY_GEMINI_SPEND_USD`.

### 5.5 Security (from `rate-limiting-abuse.md §13`)

```yaml
- alert: SsrfAttempts
  expr: rate(url_fetch_blocked_total{reason="private_ip"}[1h]) * 3600 > 5
  for: 0m
  severity: page
  annotations:
    summary: "More than 5 SSRF attempts in the last hour — someone is probing"

- alert: PerUserRateLimitAbuse
  expr: |
    rate(rate_limit_exceeded_total{scope="per-user-hourly"}[1h]) * 3600 > 20
  for: 0m
  severity: warn
  annotations:
    summary: "A user is hitting per-user-hourly rate limit more than 20 times/hour — consider denylist"
```

### 5.6 RC webhook lag

```yaml
- alert: RcWebhookLagHigh
  expr: |
    histogram_quantile(0.95,
      rate(rc_webhook_lag_ms_bucket[1h])
    ) > 1_800_000    # 30 minutes
  for: 10m
  severity: warn
  annotations:
    summary: "RC webhook p95 delivery lag above 30 minutes — subscription state may be stale"
```

### 5.7 Dependencies

```yaml
- alert: PostgresUnhealthy
  expr: health_dep_degraded{dep="postgres"} == 1
  for: 2m
  severity: page
  annotations:
    summary: "Postgres reported unhealthy by /health for 2 minutes"

- alert: RedisUnhealthy
  expr: health_dep_degraded{dep="redis"} == 1
  for: 5m
  severity: warn
  annotations:
    summary: "Redis unhealthy — rate limiting falling back to in-memory"
```

---

## 6. Dashboards

One Grafana dashboard: **GFM API Overview**. Panels in display order:

| Panel | Type | Query |
|---|---|---|
| Requests/min | Time series | `rate(http_requests_total[1m])` grouped by `route` |
| p50 / p95 / p99 latency — `/ai/generate` | Time series | `histogram_quantile(0.{50,95,99}, rate(...bucket[5m]))` |
| 5xx error rate | Stat + time series | `rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])` |
| Gemini error rate | Stat + time series | See §5.3 expr |
| Gemini daily spend | Gauge with threshold lines at 70% and 90% of cap | `gemini_spend_usd_today` |
| Quota exceeded / min | Time series | `rate(quota_exceeded_total[1m])` by `tier` |
| Rate limit hits | Time series | `rate(rate_limit_exceeded_total[5m])` by `scope` |
| SSRF attempts / hour | Stat | `rate(url_fetch_blocked_total{reason="private_ip"}[1h]) * 3600` |
| RC webhook lag p95 | Stat | `histogram_quantile(0.95, rate(rc_webhook_lag_ms_bucket[1h]))` |
| RC webhook outcomes | Time series | `rate(rc_webhook_total[5m])` by `outcome` |
| Dependency health | State timeline | `health_dep_degraded` by `dep` |

---

## 7. PM2 Log Management

PM2 captures stdout/stderr from the Node process. Configure log rotation to prevent disk exhaustion on the single VPS:

```js
// ecosystem.config.js
module.exports = {
  apps: [{
    name: "gfm-api",
    script: "dist/index.js",
    log_date_format: "",           // pino already includes timestamp; disable PM2 prefix
    merge_logs: true,              // single file across cluster workers
    max_memory_restart: "1G",
    env_production: {
      NODE_ENV: "production",
      LOG_LEVEL: "info",
    },
  }],
};
```

```bash
# Install PM2 log rotation module (one-time)
pm2 install pm2-logrotate
pm2 set pm2-logrotate:max_size 50M
pm2 set pm2-logrotate:retain 14        # 14 rotated files = ~2 weeks at typical volume
pm2 set pm2-logrotate:compress true
```

Logs are newline-delimited JSON at `/root/.pm2/logs/gfm-api-out.log`. To grep a production incident:

```bash
grep '"request_id":"<id>"' /root/.pm2/logs/gfm-api-out.log | jq .
grep '"generation_id":"<uuid>"' /root/.pm2/logs/gfm-api-out.log | jq .
```

---

## 8. Acceptance Checklist

- [x] **Every request logs: `request_id`, `user_id`, `route`, `status`, `latency_ms`, `gemini_input_tokens`, `gemini_output_tokens`**
  → §2.2: all seven fields defined on the response log line, with source and type. `pino` child logger bound per-request in §2.1.

- [x] **Metrics defined: requests/min, p50/p95/p99 latency, Gemini error rate, quota-exceeded rate, RC webhook lag**
  → §3.1 (`http_request_duration_ms` histogram + `http_requests_total` counter), §3.2 (`gemini_requests_total`), §3.3 (`quota_exceeded_total`), §3.6 (`rc_webhook_lag_ms` histogram). Prometheus queries for all five derived metrics given in §3 and §5.

- [x] **Error tracker (Sentry or similar) captures unhandled errors with `user_id` tag**
  → §4.1–§4.3: Sentry initialized with `requestHandler` + `errorHandler`; `Sentry.setUser({ id })` called in auth middleware; §4.3 table distinguishes captured vs expected errors.

- [x] **Alert thresholds proposed (e.g., Gemini error rate >5% for 5min)**
  → §5: six alert groups — availability (§5.1), latency (§5.2), Gemini (§5.3), cost (§5.4), security (§5.5), RC lag (§5.6), deps (§5.7). Gemini error rate alert at >5% (warn) and >20% (page) over 5min, as specified.

- [x] **`rate-limiting-abuse.md §13` hooks all surfaced**
  → `rate_limit_exceeded_total{scope, route}` (§3.4), `kill_switch_tripped_total{which}` (§3.4), `cost_breaker_tripped_total{scope}` (§3.4), `url_fetch_blocked_total{reason}` (§3.5, covers `ssrf.blocked` via `reason="private_ip"` label), `gemini_spend_usd_today` gauge (§3.2), `health_dep_degraded{dep}` gauge (§3.7). All four suggested alert thresholds from §13 covered in §5.4–§5.5.
