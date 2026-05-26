# Middleware API Contract

**Version:** 2.0
**Last updated:** 2026-05-26
**Owner:** Backend (`gfm_mw` — Node + Express on Hostinger VPS)
**Consumers:** Flutter app, RevenueCat webhook delivery, Google Cloud Pub/Sub
**Source of truth:** This document. Behavior the schema can't express is in prose §4.

---

## 1. Overview

This document specifies the HTTP contract between:

- The Flutter app and the GFM middleware (AI generation, quota, push notifications, purchase sync)
- RevenueCat and the middleware (`/webhooks/revenuecat`)
- Google Cloud Pub/Sub and the middleware (`/webhooks/forms-watch`)
- The browser-based admin UI and the middleware (`/admin/*`)

**Base URL (production):** `https://gfm.robi-dev.tech`

TLS is mandatory — iOS ATS blocks plain HTTP.

**Versioning policy:** No `/v1/` prefix. Breaking changes are introduced via deprecation:

1. Add new field/endpoint alongside the old.
2. Mark old field as deprecated in this doc + server response headers (`Deprecation: true`, `Sunset: <date>`).
3. Remove only after all clients in the wild have updated.

The response shape for `/ai/generate` was designed to be forward-compatible with an async/queue model (see §4.1).

---

## 2. Conventions

### 2.1 Authentication

| Endpoint family | Scheme | Header |
|---|---|---|
| `POST /ai/*` | Google ID token | `Authorization: Bearer <id_token>` |
| `GET /user/status`, `POST /user/*` | Google ID token | `Authorization: Bearer <id_token>` |
| `POST /devices`, `DELETE /devices/*` | Google ID token | `Authorization: Bearer <id_token>` |
| `POST /watches`, `DELETE /watches/*` | Google ID token, premium-only | `Authorization: Bearer <id_token>` |
| `POST /webhooks/revenuecat` | RC bearer secret | `Authorization: <plain secret>` |
| `POST /webhooks/forms-watch` | Pub/Sub OIDC | `Authorization: Bearer <oidc jwt>` |
| `/admin/*` (except `/admin/login`) | Admin bearer | `Authorization: Bearer <ADMIN_TOKEN>` |
| `GET /health`, `GET /metrics` | Health bearer | `Authorization: Bearer <HEALTH_TOKEN>` |
| `GET /ping` | Public | — |

**Google ID token verification.** The server verifies the JWT signature, `aud`, `iss`, and `exp` against Google's public keys (`https://www.googleapis.com/oauth2/v3/certs`). Audience must match **either** `GOOGLE_CLIENT_ID` (web) **or** `GOOGLE_IOS_CLIENT_ID` (iOS) — iOS issues tokens with the iOS client ID as audience. The stable identity is the `sub` claim.

**RevenueCat auth.** RC sends the configured shared secret as a **plain bearer token** in the `Authorization` header. The middleware constant-time-compares it against `RC_WEBHOOK_SECRET` using `crypto.timingSafeEqual`. (Earlier drafts of this doc described HMAC-SHA256 — that was incorrect and never matched RC's actual delivery.)

**Pub/Sub OIDC.** Incoming Forms-watch deliveries carry an OIDC JWT. The middleware verifies the signature against Google's public keys and checks `aud == FORMS_PUBSUB_AUDIENCE` (= the public webhook URL).

### 2.2 Required headers

| Header | Required on | Notes |
|---|---|---|
| `Authorization` | All non-public endpoints | Per §2.1 |
| `Content-Type: application/json` | All JSON POSTs | UTF-8 |
| `Idempotency-Key` | `POST /ai/generate` | UUIDv4 string. Client generates once per logical attempt and reuses on retry. |
| `X-Request-Id` | Optional, all endpoints | Client-supplied trace ID. If absent, server generates one. Echoed in `X-Request-Id` response header. |

### 2.3 Time format

All timestamps are RFC3339 UTC with millisecond precision and a trailing `Z`:

```
2026-05-08T14:32:11.412Z
```

### 2.4 ID formats

| ID | Format | Source |
|---|---|---|
| `generationId` | UUIDv4 | Server-generated |
| `Idempotency-Key` | UUIDv4 | Client-generated |
| `X-Request-Id` | Free-form string ≤ 64 chars | Client or server |
| RC `event_id` | RC-defined (UUID-like) | RevenueCat |
| FCM device token | Opaque string | Firebase SDK on device |

### 2.5 Error envelope

**Every** non-2xx response uses the same shape:

```json
{
  "code": "snake_case_machine_readable",
  "message": "Human-readable, safe to display",
  "details": { "...": "..." }
}
```

- `code` is stable across versions and is the field clients branch on.
- `message` is for humans (logs, debug screens). Wording may change without notice.
- `details` is optional and varies per code (see §6).

The full catalog is in §6. Clients **must** treat unknown codes as generic errors of the matching HTTP status class.

### 2.6 Client retry guidance

| HTTP | Retryable? | Strategy |
|---|---|---|
| 200 | n/a | — |
| 400 | No | Fix request, do not retry |
| 401 | No | Refresh ID token, retry once |
| 403 | No | Show paywall or denylist message |
| 409 | No | Generate a fresh `Idempotency-Key` (or honor the new `quotaCost` and retry) |
| 429 | Show quota UI / wait `Retry-After` | Do not auto-retry on `quota_exceeded` |
| 503 | Yes | Exponential backoff: 1s → 3s → 8s, max 3 attempts. **Reuse the same `Idempotency-Key`** so the server doesn't double-charge if it actually completed. |
| 5xx other | Yes | Same backoff |
| Network error | Yes | Same backoff with same key |

The server itself retries Gemini 5xx **once** with 500ms backoff before giving up and returning 503 to the client.

---

## 3. Endpoint inventory

### 3.1 AI

| Method | Path | Auth | Notes |
|---|---|---|---|
| `POST` | `/ai/generate` | Google ID token | Main generation endpoint. Idempotency-Key required. |
| `POST` | `/ai/pdf-page-count` | Google ID token | Pre-flight quota cost for `inputType` `pdf` or `book`. |

### 3.2 User & purchase

| Method | Path | Auth | Notes |
|---|---|---|---|
| `GET`  | `/user/status` | Google ID token | Quota balance + premium state. |
| `POST` | `/user/apple/check` | Google ID token | Pre-purchase: confirms an Apple `original_transaction_id` isn't bound to another account. |
| `POST` | `/user/purchase/sync` | Google ID token | App-triggered RC reconcile. Server fetches from `https://api.revenuecat.com/v1/subscribers/{sub}` using `RC_SECRET_API_KEY`. |

### 3.3 Push notifications

| Method | Path | Auth | Notes |
|---|---|---|---|
| `POST`   | `/devices` | Google ID token | Register an FCM device token. |
| `DELETE` | `/devices/:token` | Google ID token | Unregister a device token. |
| `POST`   | `/watches` | Google ID token, premium-only | Create a Google Forms `watch`. |
| `DELETE` | `/watches/:watchId` | Google ID token | Delete a watch. |

### 3.4 Webhooks

| Method | Path | Auth | Notes |
|---|---|---|---|
| `POST` | `/webhooks/revenuecat` | RC bearer secret | RC event ingestion (see §4.2). |
| `POST` | `/webhooks/forms-watch` | Pub/Sub OIDC | Forms response → FCM fan-out. Idempotent via `processed_pubsub_messages.message_id`. |

### 3.5 Admin

| Method | Path | Notes |
|---|---|---|
| `POST` | `/admin/login` | Email + password → bearer token (validated against `ADMIN_EMAIL` / `ADMIN_PASSWORD`). |
| `GET / PATCH` | `/admin/config` | Read / mutate DB-backed `configService` keys. |
| `GET / PATCH` | `/admin/quota-products`, `/admin/quota-products/:id` | Manage per-product quota grants. |
| `GET / POST / DELETE` | `/admin/whitelist`, `/admin/whitelist/:email` | Manage `quota_whitelist`. |
| Static | `/admin/*` | Vite-built admin UI served from `dist/admin-dist`. |

### 3.6 Ops

| Method | Path | Notes |
|---|---|---|
| `GET` | `/ping` | Public liveness probe (no auth, no DB). |
| `GET` | `/health` | Auth-gated full health check. |
| `GET` | `/metrics` | Auth-gated Prometheus exposition. |

---

## 4. Endpoint behavior (non-schema)

### 4.1 `POST /ai/generate`

**Purpose.** Generate a Google-Forms-shaped JSON form from user input. The Flutter client materializes the response into Forms API `batchUpdate` calls.

#### Input variants

| `inputType` | Allowed tier | Required fields | Limits |
|---|---|---|---|
| `text`    | free + premium | `prompt` | ≤ 4000 chars |
| `pdf`     | premium only | `fileBase64` | ≤ 5MB decoded; multi-quota cost by page count |
| `youtube` | premium only | `youtubeUrl` | Single URL; counts against `YOUTUBE_MONTHLY_MINUTES` budget |
| `urls`    | premium only | `urls` | 1–5 URLs; each fetched server-side (SSRF-guarded) and Readability-stripped |
| `book`    | premium only | `fileBase64` (chapter PDF), optional `chapterTitle` | ≤ 5MB decoded; multi-quota cost |

Free users sending any non-`text` `inputType` get **403 `premium_required`**. Whitelisted users are treated as premium.

#### Idempotency contract

- `Idempotency-Key` is **required**. Missing or non-UUIDv4 → 400 `missing_idempotency_key`.
- Same key + same canonical body → cached success returned (200) without re-running generation or re-debiting quota.
- Same key + different canonical body → 409 `idempotency_conflict` with `originalRequestHash`.
- Same key + previous attempt failed → re-runs generation; cache only stores successes.
- Concurrent retry with the first still in-flight → 409 `idempotency_in_flight` (client should wait 1s and retry). After 2 minutes the server takes over the row.

See §5 for the full state machine.

#### PDF / book quota cost

For `pdf` and `book`, server cost is `ceil(pages / PDF_PAGES_PER_QUOTA)` (default `PDF_PAGES_PER_QUOTA = 50`). Clients should call `POST /ai/pdf-page-count` first and send the returned `quotaCost` in the request body's `confirmedQuotaCost` field. If the server-computed cost no longer matches at generate time, returns **409 `quota_cost_changed`** so the client can re-confirm before being charged.

#### Server retry behavior

On AI provider 5xx, the server retries **once** after 500ms. On the second failure → 503 `gemini_unavailable`. Total budget to the client: 30s for text/urls, 60s for pdf/book, 180s for youtube. After the deadline, 503 `gemini_timeout`.

#### Quota burn

Quota is debited **only on a successful 200**. All failure modes (4xx, 503) leave `users.quota_balance` untouched but still write a row to `ai_generations` for audit / abuse monitoring.

#### Forward-compatibility for async

The 200 response includes `status` so we can move generation off the request thread without a v2 rev:

- Today (sync): `status: "completed"`, `form` present.
- Future (async): `status: "pending"`, no `form`. Client polls `GET /ai/generations/{generationId}` (not yet implemented).

Clients should treat `status` as authoritative — not just check for `form`.

### 4.2 `POST /webhooks/revenuecat`

**Purpose.** Reconcile subscription state from RevenueCat into the DB.

#### Processing order

1. **Verify bearer secret.** `crypto.timingSafeEqual` of header value against `RC_WEBHOOK_SECRET`. Fail → 401, no DB writes.
2. **Parse envelope.** Missing `event.id` / `event.type` → 400 `invalid_input`.
3. **Dedupe pre-check.** `SELECT 1 FROM webhook_events WHERE event_id = $1` — if found, log + 200 silently. Authoritative guard is the `UNIQUE` constraint in step 6.
4. **Resolve user** by `event.app_user_id` → `users.google_sub`. If unknown (config drift or new user who hasn't signed in yet), store the event with `user_id = NULL` for audit / orphan replay and return 200.
5. **Apply event.** `application/rc-webhook/apply-event.ts` handles all 7 event types (`INITIAL_PURCHASE`, `RENEWAL`, `NON_RENEWING_PURCHASE`, `PRODUCT_CHANGE`, `BILLING_ISSUE`, `EXPIRATION`, `CANCELLATION`). See `revenuecat-webhook-map.md`.
6. **Commit.** `INSERT INTO webhook_events` + user update in one transaction. The `UNIQUE(event_id)` constraint is the authoritative dedupe guard.
7. **Return 200** with `{ "received": true }`.

Sandbox events (`event.environment === "SANDBOX"`) are currently processed identically to production for pre-launch testing. Re-introduce a gate before public sign-ups so external sandbox Apple IDs can't credit real quota.

#### Failure modes

- Auth mismatch → 401 `invalid_signature`.
- Malformed JSON → 400 `invalid_input`.
- DB write failure → 503 `database_unavailable`. RC retries on 5xx — transient outages heal automatically.
- Unknown event type → log warning, store row, return 200. Don't break on new RC event types.

#### Orphan replay

`auth.middleware.ts` calls `replayOrphanedEvents(sub, user.id)` on first user upsert. Any `webhook_events` row with `user_id IS NULL` matching this `google_sub` gets re-applied. Fire-and-forget — doesn't block the sign-in request.

### 4.3 `GET /user/status`

**Purpose.** Render the AI Form Builder entry point, the paywall, editor's premium-gated controls, and the YouTube-minutes meter.

#### Response shape (current — balance-based)

See §3 `UserStatusResponse`. Tier counters (`aiFreeUsed` / `aiFreeLimit` / etc.) were removed in migration 004 — clients see `quotaBalance` (integer) and `unlimited` (boolean for whitelisted users).

#### Lazy free-grant

For free-tier users only: if `users.free_quota_reset_at` is NULL or has passed, the server credits the configured free product's quota amount and rolls `free_quota_reset_at` forward by 30 days **before** returning the response. The grant is idempotent — the CTE in `applyFreeGrantIfDue` only credits when the condition is met. This makes the AI Builder show the correct "remaining" count on first open without requiring a separate generation.

(Premium grants happen only on RC `INITIAL_PURCHASE` / `RENEWAL` / `PRODUCT_CHANGE` webhooks — never on read.)

#### Whitelist override

If `quota_whitelist` contains the user's email, the response sets `unlimited: true` and `isPremium: true`. The user's actual `quota_balance` value is still returned (informational only). Gating logic in the app and middleware treats `unlimited === true` as bypassing both free-quota gates and premium-only gates.

### 4.4 `POST /user/apple/check`

Body: `{ "original_transaction_id": "<storekit id>" }`.

Returns:
- `{ "allowed": true }` if the transaction is not bound to anyone, or is already bound to the calling user.
- `{ "allowed": false, "message": "…" }` if bound to a different `user_id` — the app shows the message and refuses to start the purchase.

### 4.5 `POST /user/purchase/sync`

Reconciles by fetching `https://api.revenuecat.com/v1/subscribers/{google_sub}` with the server's `RC_SECRET_API_KEY` (different from `RC_WEBHOOK_SECRET`). If the user is entitled and the webhook hasn't credited yet, it credits + sets `subscription_product_id` (`ref_id = "sync-heal:<sub>:<productId>"` for traceability). If the webhook has already run, it heals subscription metadata only — no double credit. Returns `{ "synced": true }` or `{ "synced": false }`. Returns 503 `unavailable` if `RC_SECRET_API_KEY` is not configured.

### 4.6 `POST /webhooks/forms-watch`

Receives Pub/Sub push deliveries containing Forms `responses.received` events. Verified via OIDC, deduplicated via `processed_pubsub_messages.message_id`, fans out to all of the watching user's registered device tokens via FCM multicast, and prunes invalid tokens. Returns 503 on FCM failure so Pub/Sub retries; 200 otherwise. Notification title/body use `NOTIFICATION_TITLE_TEMPLATE` / `NOTIFICATION_BODY_TEMPLATE` (admin-configurable; supports `{formTitle}` placeholder).

---

## 5. Idempotency state machine for `POST /ai/generate`

### 5.1 Cache scope

| What | Cached? |
|---|---|
| 200 success (`status=completed`) | **Yes**, until the `ai_generations` row is purged |
| 503 / 5xx errors | **No** — retries re-run the generation |
| 400 / 401 / 403 / 409 | **No** (and never reach the cache anyway — fail before processing) |

Cache key: `(user_id, idempotency_key)` enforced by `UNIQUE` constraint on `ai_generations`.

### 5.2 Body hashing

The "is this the same request" check uses SHA-256 over the **canonicalized** JSON body:

1. Parse JSON → object.
2. Sort all object keys lexicographically, recursively.
3. Serialize with no whitespace.
4. SHA-256, hex-encoded.

Stored in `ai_generations.request_hash`.

### 5.3 Decision tree

```
on POST /ai/generate (auth, input validation, premium gate, quota gate already passed):

  let key = headers["Idempotency-Key"]
  let hash = sha256(canonicalize(body))

  row = SELECT * FROM ai_generations
        WHERE user_id = $userId AND idempotency_key = $key
        FOR UPDATE

  if row is null:
    INSERT INTO ai_generations (user_id, idempotency_key, request_hash, status='processing', ...)
    proceed to generate (§5.4)

  else if row.request_hash != hash:
    return 409 idempotency_conflict
        details: { originalRequestHash: row.request_hash }

  else if row.status == 'success':
    return cached response (200 with row.output_json, row.generation_id)

  else if row.status == 'processing':
    if (now - row.created_at) < 2 min:
      return 409 idempotency_in_flight
    else:
      takeover — proceed to generate (§5.4)

  else:  // status in ('gemini_error', 'validation_error', 'failed')
    UPDATE ai_generations SET status='processing', error_payload=null WHERE id = row.id
    proceed to generate (§5.4)
```

### 5.4 Post-generation

```
on AI success + schema validation pass:
  UPDATE ai_generations SET
    status='success',
    output_json = $form,
    input_tokens, output_tokens, ...
  userRepo.debitQuota($userId, $quotaCost)        // skipped for whitelist
  return 200

on AI failure or validation failure:
  UPDATE ai_generations SET
    status='gemini_error' | 'validation_error' | 'failed',
    error_payload = $errorDetails
  // do NOT debit quota
  return 503 with appropriate code
```

### 5.5 Concurrency

The `FOR UPDATE` lock serializes concurrent retries on the same `(user_id, key)` pair. A second concurrent request blocks until the first completes, then sees the result and either returns the cache or proceeds appropriately. No double-charge, no double Gemini call.

---

## 6. Error code catalog

Every `code` value the server can emit. Stable across versions.

| HTTP | `code` | Where | Retryable | `details` includes | Meaning |
|---|---|---|---|---|---|
| 400 | `invalid_input` | any | No | per-field issues when available | Schema validation failed |
| 400 | `missing_idempotency_key` | `/ai/generate` | No | — | Header absent or not UUIDv4 |
| 400 | `file_too_large` | `/ai/generate` (pdf/book) | No | `maxBytes`, `actualBytes` | Decoded base64 > 5MB |
| 400 | `unsupported_input_type` | `/ai/generate` | No | `inputType` | `inputType` not in enum |
| 400 | `url_fetch_failed` | `/ai/generate` (urls) | No | `url`, `reason` | URL unreachable, blocked by SSRF guard, or wrong content-type |
| 400 | `youtube_unavailable` | `/ai/generate` (youtube) | No | `url` | YouTube rejected the URL (private/removed/region-locked) |
| 401 | `invalid_token` | bearer endpoints | No (re-auth) | — | Google ID token failed verification |
| 401 | `invalid_signature` | `/webhooks/revenuecat` | No | — | RC bearer secret mismatch |
| 403 | `premium_required` | `/ai/generate` | No | `requiredEntitlement: "GFMPremium"`, `requestedInputType` | Free user requested PDF/YouTube/URLs/book |
| 403 | `user_blocked` | any | No | — | User on `USER_DENYLIST` |
| 409 | `idempotency_conflict` | `/ai/generate` | No (new key) | `originalRequestHash` | Same key, different body |
| 409 | `idempotency_in_flight` | `/ai/generate` | Yes (after 1s) | — | Concurrent retry; first still processing |
| 409 | `quota_cost_changed` | `/ai/generate` (pdf/book) | Yes (after re-confirm) | `confirmedQuotaCost`, `actualQuotaCost` | Server-computed cost differs from client's pre-flight value |
| 429 | `quota_exceeded` | `/ai/generate` | At reset | `tier`, `balance`, `quotaCost` | Insufficient `quota_balance` for this request |
| 429 | `rate_limited` | `/ai/generate` | At `retryAfter` | `retryAfter` (s) | Per-IP or per-user rate limit hit |
| 503 | `gemini_unavailable` | `/ai/generate` | Yes | — | AI provider 5xx after 1 retry |
| 503 | `gemini_timeout` | `/ai/generate` | Yes | — | Deadline exceeded (30/60/180s by input type) |
| 503 | `validation_error` | `/ai/generate` | Yes | — | AI output failed schema after 1 repair attempt |
| 503 | `service_disabled` | `/ai/generate` | Maybe later | — | `AI_GENERATION_DISABLED` active |
| 503 | `service_busy` | `/ai/generate` | Yes | `retryAfter` (s) | Global limiter hit |
| 503 | `daily_budget_exceeded` | `/ai/generate` | At UTC midnight | — | `MAX_DAILY_GEMINI_SPEND_USD` hit |
| 503 | `database_unavailable` | any | Yes | — | Postgres connection failed |
| 503 | `unavailable` | `/user/purchase/sync` | Configurable | — | `RC_SECRET_API_KEY` not configured |

Unknown codes → treat as generic error of the matching HTTP class. New codes are only added — never repurposed.

---

## 7. Schemas

The shapes the API emits and accepts. Inline rather than OpenAPI to stay readable for the agents that maintain this file.

### 7.1 `GenerateRequest` (oneOf by `inputType`)

```jsonc
// text
{ "inputType": "text",
  "prompt": "string 1..4000",
  "questionCountHint": 3..50  // optional, default 5–15
}

// pdf
{ "inputType": "pdf",
  "fileBase64": "<base64 PDF, ≤5MB decoded>",
  "fileName": "string ≤255",                 // optional
  "confirmedQuotaCost": <int>,                // required; from /ai/pdf-page-count
  "questionCountHint": 3..50
}

// youtube
{ "inputType": "youtube",
  "youtubeUrl": "^https?://(www\\.)?(youtube\\.com/watch\\?v=|youtu\\.be/)[A-Za-z0-9_-]{11}",
  "questionCountHint": 3..50
}

// urls
{ "inputType": "urls",
  "urls": [ "^https?://...", ... ],          // 1..5
  "questionCountHint": 3..50
}

// book
{ "inputType": "book",
  "fileBase64": "<base64 PDF, ≤5MB decoded>",
  "fileName":     "string ≤255",             // optional
  "chapterTitle": "string ≤255",             // optional
  "confirmedQuotaCost": <int>,
  "questionCountHint": 3..50
}
```

### 7.2 `GenerateResponse`

```jsonc
{
  "generationId": "<uuid>",
  "status": "completed" | "pending",
  "form": Form,                  // present iff status == "completed"
  "tokensUsed": { "input": <int>, "output": <int> },
  "quota": QuotaSnapshot
}
```

### 7.3 `Form` and `Question`

Field set per question type is the same as before (see `ai-prompt-spec.md` for full per-type rules):

```jsonc
{
  "title": "string 1..300",
  "description": "string 0..2000",
  "isQuiz": true | false,                    // model-decided per prompt v3
  "questions": [ Question, ... ]             // 1..50
}

Question:
{
  "title": "string 1..1000",
  "description": "string 0..2000",
  "required": true | false,
  "type":
    "SHORT_ANSWER" | "PARAGRAPH" |
    "MULTIPLE_CHOICE" | "CHECKBOXES" | "DROPDOWN" |
    "LINEAR_SCALE" | "DATE" | "TIME" | "RATING",
  "options": ["string", ...],                 // 2..20 entries; required for choice types
  "scaleMin": 0 | 1,
  "scaleMax": 2..10,
  "scaleMinLabel": "string ≤50",
  "scaleMaxLabel": "string ≤50",
  "ratingScale": 3 | 5 | 10,
  // Quiz fields — present only when top-level isQuiz=true and type is gradeable
  "correctAnswers": ["string", ...],
  "pointValue": 0..100,
  "whenRight": "string",
  "whenWrong": "string"
}
```

### 7.4 `QuotaSnapshot`

```jsonc
{
  "balance":   <int>,    // remaining after this request
  "quotaCost": <int>,    // what this request cost (1 for text/youtube/urls, ceil(pages/N) for pdf/book)
  "unlimited": true | false
}
```

### 7.5 `UserStatusResponse`

```jsonc
{
  "isPremium":               true | false,
  "quotaBalance":            <int>,
  "unlimited":               true | false,     // whitelist override
  "gracePeriodUntil":        "<rfc3339>" | null,
  "subscriptionProductId":   "GFM_Weekly_3.99" | "GFM_Monthly_4.99" | "GFM_Yearly_44.99" | "free" | null,
  "youtubeMinutesUsed":      <int>,
  "youtubeMinutesLimit":     <int>,
  "youtubeMinutesResetsAt":  "<rfc3339>" | null
}
```

### 7.6 `ErrorBody`

```jsonc
{
  "code":    "snake_case",
  "message": "human-readable",
  "details": { ... }            // optional; per-code shape
}
```

---

## 8. Examples

### 8.1 `POST /ai/generate` — success (text, free tier)

**Request**

```http
POST /ai/generate HTTP/1.1
Host: gfm.robi-dev.tech
Authorization: Bearer eyJhbGc...
Content-Type: application/json
Idempotency-Key: 8b1c1f8a-2e4f-4e16-9f12-1a2b3c4d5e6f
X-Request-Id: dashboard-2026-05-26T14:32:11

{
  "inputType": "text",
  "prompt": "Customer feedback survey for a small bakery."
}
```

**Response — 200**

```json
{
  "generationId": "8b8e1f9c-d301-4f47-a3a3-9c1e2d4f7a89",
  "status": "completed",
  "form": {
    "title": "Bakery Customer Feedback",
    "description": "Help us improve! This survey takes 2 minutes.",
    "isQuiz": false,
    "questions": [
      { "title": "How often do you visit?", "type": "MULTIPLE_CHOICE", "required": true,
        "options": ["First time", "Once a month", "Weekly", "Several times a week"] },
      { "title": "Any suggestions?", "type": "PARAGRAPH", "required": false }
    ]
  },
  "tokensUsed": { "input": 218, "output": 412 },
  "quota": { "balance": 2, "quotaCost": 1, "unlimited": false }
}
```

### 8.2 Premium gate (free user sends PDF)

**Response — 403**

```json
{
  "code": "premium_required",
  "message": "This input type requires a premium subscription.",
  "details": {
    "requiredEntitlement": "GFMPremium",
    "requestedInputType": "pdf"
  }
}
```

### 8.3 Quota exceeded (free user, no balance)

**Response — 429**

```json
{
  "code": "quota_exceeded",
  "message": "This request costs 1 quota but you only have 0 remaining.",
  "details": { "tier": "free", "balance": 0, "quotaCost": 1 }
}
```

### 8.4 Idempotency replay (cached success)

Second request, same key, same canonical body → 200 with the same `generationId` and `form`. `quota` reflects the post-debit state from the original success.

### 8.5 Idempotency conflict

```http
POST /ai/generate
Idempotency-Key: 8b1c1f8a-2e4f-4e16-9f12-1a2b3c4d5e6f    # reused from §8.1
{ "inputType": "text", "prompt": "Different prompt entirely" }
```

**Response — 409**

```json
{
  "code": "idempotency_conflict",
  "message": "This Idempotency-Key was used with a different request body. Use a fresh key.",
  "details": { "originalRequestHash": "8f4c2b3e1a..." }
}
```

### 8.6 PDF quota-cost changed mid-flow

**Response — 409**

```json
{
  "code": "quota_cost_changed",
  "message": "The quota cost changed (was 1, now 2). Please try again.",
  "details": { "confirmedQuotaCost": 1, "actualQuotaCost": 2 }
}
```

Client re-confirms via `/ai/pdf-page-count` and retries `/ai/generate` with the updated `confirmedQuotaCost`.

### 8.7 Gemini transient failure

**Response — 503**

```json
{
  "code": "gemini_unavailable",
  "message": "The AI service is temporarily unavailable. Please try again in a moment."
}
```

Client retries with the **same** `Idempotency-Key` after 1s → 3s → 8s. If a retry succeeds, that's when quota burns.

### 8.8 `GET /user/status`

**Free user, never used AI (lazy grant applied)**

```json
{
  "isPremium": false,
  "quotaBalance": 3,
  "unlimited": false,
  "gracePeriodUntil": null,
  "subscriptionProductId": null,
  "youtubeMinutesUsed": 0,
  "youtubeMinutesLimit": 300,
  "youtubeMinutesResetsAt": null
}
```

**Premium user mid-period**

```json
{
  "isPremium": true,
  "quotaBalance": 38,
  "unlimited": false,
  "gracePeriodUntil": null,
  "subscriptionProductId": "GFM_Monthly_4.99",
  "youtubeMinutesUsed": 42,
  "youtubeMinutesLimit": 300,
  "youtubeMinutesResetsAt": "2026-06-01T00:00:00.000Z"
}
```

**Whitelisted user**

```json
{
  "isPremium": true,
  "quotaBalance": 3,
  "unlimited": true,
  "gracePeriodUntil": null,
  "subscriptionProductId": null,
  "youtubeMinutesUsed": 0,
  "youtubeMinutesLimit": 300,
  "youtubeMinutesResetsAt": null
}
```

### 8.9 `POST /webhooks/revenuecat` — INITIAL_PURCHASE

**Request** (truncated)

```http
POST /webhooks/revenuecat
Authorization: <plain RC_WEBHOOK_SECRET>
Content-Type: application/json

{
  "event": {
    "id": "rc-evt-abc123",
    "type": "INITIAL_PURCHASE",
    "app_user_id": "google-sub-1234567890",
    "entitlement_ids": ["GFMPremium"],
    "product_id": "GFM_Monthly_4.99",
    "expiration_at_ms": 1717200000000,
    "environment": "PRODUCTION"
  }
}
```

**Response — 200**

```json
{ "received": true }
```

Same response on duplicate delivery — dedupe is silent.

### 8.10 `POST /webhooks/revenuecat` — invalid signature

```json
{
  "code": "invalid_signature",
  "message": "Webhook signature verification failed."
}
```

No DB writes. RC will retry — fix the secret.

### 8.11 `POST /user/apple/check`

**Request**

```http
POST /user/apple/check
Authorization: Bearer <id_token>
{ "original_transaction_id": "1000000123456789" }
```

**Response — 200, allowed**

```json
{ "allowed": true }
```

**Response — 200, blocked**

```json
{
  "allowed": false,
  "message": "This Apple ID already has a subscription linked to another account. Please use a different Apple ID or go to Settings and change your Apple ID."
}
```

### 8.12 `POST /user/purchase/sync`

**Response — webhook had already credited**

```json
{ "synced": true, "via": "heal-only" }
```

**Response — webhook hadn't run; sync credited**

```json
{ "synced": true, "via": "sync-heal" }
```

**Response — RC says user is not entitled**

```json
{ "synced": false }
```
