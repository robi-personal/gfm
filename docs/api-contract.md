# AI Form Builder — API Contract

**Status:** Draft (Task 1 of Phase 2)
**Owner:** Backend (Node + Express on Hostinger VPS)
**Consumers:** Flutter app, RevenueCat webhook delivery
**Source of truth:** This document. Anything in `Tasks.md` that conflicts with this doc is older and should be updated.

---

## 1. Overview

This document specifies the HTTP contract between:

- The Flutter app and the AI middleware (`/ai/generate`, `/user/status`)
- RevenueCat and the AI middleware (`/webhooks/revenuecat`)

**Base URL:** `https://api.<domain>.com` (TLS required — iOS ATS blocks plain HTTP).

**Versioning policy:** No `/v1/` prefix. Breaking changes are introduced via deprecation:

1. Add new field/endpoint alongside the old.
2. Mark old field as deprecated in this doc + server response headers (`Deprecation: true`, `Sunset: <date>`).
3. Remove only after all clients in the wild have updated.

The response shape was designed to be forward-compatible with an async/queue model (see §4.1) so clients written today will not need a `v2` when we move generation off the request thread.

---

## 2. Conventions

### 2.1 Authentication

| Endpoint | Scheme | Header |
|---|---|---|
| `POST /ai/generate` | Google ID token (Bearer) | `Authorization: Bearer <id_token>` |
| `GET /user/status` | Google ID token (Bearer) | `Authorization: Bearer <id_token>` |
| `POST /webhooks/revenuecat` | RevenueCat HMAC-SHA256 | `Authorization: <hex-hmac>` |

**Google ID token verification:** server verifies the JWT signature, `aud`, `iss`, and `exp` against Google's public keys (`https://www.googleapis.com/oauth2/v3/certs`). The user's stable identity is the `sub` claim.

**RevenueCat HMAC:** server computes `HMAC-SHA256(rawRequestBody, RC_WEBHOOK_SECRET)`, hex-encoded, and constant-time compares against the `Authorization` header value. The shared secret is configured in the RC dashboard and stored in the server's env.

### 2.2 Required headers

| Header | Required on | Notes |
|---|---|---|
| `Authorization` | All endpoints | Per §2.1 |
| `Content-Type: application/json` | All POSTs | UTF-8 |
| `Idempotency-Key` | `POST /ai/generate` | UUIDv4 string. Client generates once per logical attempt and reuses on retry. |
| `X-Request-Id` | Optional, all endpoints | Client-supplied trace ID. If absent, server generates one. Echoed in response headers. |

### 2.3 Time format

All timestamps are RFC3339 UTC with millisecond precision and a trailing `Z`:

```
2026-05-08T14:32:11.412Z
```

### 2.4 ID formats

| ID | Format | Source |
|---|---|---|
| `generationId` | UUIDv4 string | Server-generated |
| `Idempotency-Key` | UUIDv4 string | Client-generated |
| `X-Request-Id` | Free-form string ≤ 64 chars | Client or server |
| RC `event_id` | RC-defined (UUID-like) | RevenueCat |

### 2.5 Error envelope

**Every** non-2xx response from this API uses the same shape:

```json
{
  "code": "snake_case_machine_readable",
  "message": "Human-readable, safe to display",
  "details": { "...": "..." }
}
```

- `code` is stable across versions and is the field clients should branch on.
- `message` is for humans (logs, debug screens). It may change wording without notice.
- `details` is optional and varies per error code (see §6 for what each code includes).

The full catalog of `code` values is in §6. Clients **must** treat unknown codes as generic errors of the matching HTTP status class.

### 2.6 Client retry guidance

| HTTP | Retryable? | Strategy |
|---|---|---|
| 200 | n/a | — |
| 400 | No | Fix request, do not retry |
| 401 | No | Refresh ID token, retry once |
| 403 | No | Show paywall or denylist message |
| 409 | No | Generate a fresh `Idempotency-Key` |
| 429 | At `resetsAt` | Show quota UI; do not retry until reset |
| 503 | Yes | Exponential backoff: 1s → 3s → 8s, max 3 attempts. **Reuse the same `Idempotency-Key`** so we don't double-charge if the server actually completed. |
| 5xx other | Yes | Same backoff |
| Network error | Yes | Same backoff with same key |

The server itself retries Gemini 5xx **once** with 500ms backoff before giving up and returning 503 to the client.

---

## 3. OpenAPI 3.1 specification

```yaml
openapi: 3.1.0
info:
  title: GFM AI Form Builder API
  version: 0.1.0-draft
  description: |
    Middleware API for AI-driven form generation. The Flutter app never calls
    Gemini directly — all AI traffic flows through this service.

servers:
  - url: https://api.example.com
    description: Production
  - url: https://staging.api.example.com
    description: Staging

security: []   # security applied per-operation

tags:
  - name: ai
    description: AI form generation
  - name: user
    description: User quota and subscription state
  - name: webhooks
    description: External system event ingestion

paths:
  /ai/generate:
    post:
      tags: [ai]
      summary: Generate a form from user input
      operationId: generateForm
      security:
        - googleIdToken: []
      parameters:
        - in: header
          name: Idempotency-Key
          required: true
          schema:
            type: string
            format: uuid
        - in: header
          name: X-Request-Id
          required: false
          schema:
            type: string
            maxLength: 64
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/GenerateRequest"
      responses:
        "200":
          description: Generation completed (sync) or accepted (future async)
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/GenerateResponse"
        "400":
          $ref: "#/components/responses/BadRequest"
        "401":
          $ref: "#/components/responses/Unauthorized"
        "403":
          $ref: "#/components/responses/Forbidden"
        "409":
          $ref: "#/components/responses/IdempotencyConflict"
        "429":
          $ref: "#/components/responses/QuotaExceeded"
        "503":
          $ref: "#/components/responses/ServiceUnavailable"

  /user/status:
    get:
      tags: [user]
      summary: Get current user's quota and subscription state
      operationId: getUserStatus
      security:
        - googleIdToken: []
      responses:
        "200":
          description: Current user state
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/UserStatusResponse"
        "401":
          $ref: "#/components/responses/Unauthorized"

  /webhooks/revenuecat:
    post:
      tags: [webhooks]
      summary: Ingest RevenueCat subscription events
      operationId: revenueCatWebhook
      security:
        - revenueCatHmac: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              description: Opaque RevenueCat event payload — see RC docs.
              additionalProperties: true
      responses:
        "200":
          description: Event accepted (or duplicate, deduped silently)
          content:
            application/json:
              schema:
                type: object
                properties:
                  received: { type: boolean, const: true }
                required: [received]
        "401":
          $ref: "#/components/responses/Unauthorized"

components:
  securitySchemes:
    googleIdToken:
      type: http
      scheme: bearer
      bearerFormat: JWT
      description: Google Sign-In ID token. Verified server-side against Google certs.
    revenueCatHmac:
      type: apiKey
      in: header
      name: Authorization
      description: |
        Hex-encoded HMAC-SHA256 of the raw request body, computed with the
        shared secret configured in the RC dashboard. Constant-time compared.

  schemas:

    # ---- Request: discriminated union by inputType ----

    GenerateRequest:
      oneOf:
        - $ref: "#/components/schemas/GenerateRequestText"
        - $ref: "#/components/schemas/GenerateRequestPdf"
        - $ref: "#/components/schemas/GenerateRequestYouTube"
        - $ref: "#/components/schemas/GenerateRequestUrls"
        - $ref: "#/components/schemas/GenerateRequestBook"
      discriminator:
        propertyName: inputType
        mapping:
          text:    "#/components/schemas/GenerateRequestText"
          pdf:     "#/components/schemas/GenerateRequestPdf"
          youtube: "#/components/schemas/GenerateRequestYouTube"
          urls:    "#/components/schemas/GenerateRequestUrls"
          book:    "#/components/schemas/GenerateRequestBook"

    GenerateRequestText:
      type: object
      required: [inputType, prompt]
      additionalProperties: false
      properties:
        inputType: { type: string, const: text }
        prompt:
          type: string
          minLength: 1
          maxLength: 4000
          description: Natural-language description of the desired form.
        questionCountHint:
          type: integer
          minimum: 3
          maximum: 50
          description: Optional client hint for question count. Default 10–15.

    GenerateRequestPdf:
      type: object
      required: [inputType, fileBase64]
      additionalProperties: false
      properties:
        inputType: { type: string, const: pdf }
        fileBase64:
          type: string
          format: byte
          description: |
            Base64-encoded PDF, ≤ 5MB decoded. Sent natively to Gemini —
            server does not parse PDF text.
        fileName:
          type: string
          maxLength: 255
        questionCountHint: { $ref: "#/components/schemas/QuestionCountHint" }

    GenerateRequestYouTube:
      type: object
      required: [inputType, youtubeUrl]
      additionalProperties: false
      properties:
        inputType: { type: string, const: youtube }
        youtubeUrl:
          type: string
          format: uri
          pattern: '^https?://(www\.)?(youtube\.com/watch\?v=|youtu\.be/)[A-Za-z0-9_-]{11}'
        questionCountHint: { $ref: "#/components/schemas/QuestionCountHint" }

    GenerateRequestUrls:
      type: object
      required: [inputType, urls]
      additionalProperties: false
      properties:
        inputType: { type: string, const: urls }
        urls:
          type: array
          minItems: 1
          maxItems: 5
          items:
            type: string
            format: uri
            pattern: '^https?://'
        questionCountHint: { $ref: "#/components/schemas/QuestionCountHint" }

    GenerateRequestBook:
      type: object
      required: [inputType, fileBase64]
      additionalProperties: false
      properties:
        inputType: { type: string, const: book }
        fileBase64:
          type: string
          format: byte
          description: |
            Base64-encoded PDF of a single extracted chapter, ≤ 5MB.
            Client-side chapter extraction is required — full books exceed the cap.
        chapterTitle:
          type: string
          maxLength: 255
          description: Optional. Helps the AI title the form.
        questionCountHint: { $ref: "#/components/schemas/QuestionCountHint" }

    QuestionCountHint:
      type: integer
      minimum: 3
      maximum: 50

    # ---- Response: success ----

    GenerateResponse:
      type: object
      required: [generationId, status]
      properties:
        generationId:
          type: string
          format: uuid
          description: |
            Stable identifier for this generation attempt. Returned only on
            successful (200) responses. Persisted server-side for 60 days.
        status:
          type: string
          enum: [completed, pending]
          description: |
            "completed" — form is in this response (current MVP, always sync).
            "pending"   — async generation queued; client should poll
                          GET /ai/generations/{generationId} (future work).
        form:
          $ref: "#/components/schemas/Form"
          description: Present iff status="completed".
        tokensUsed:
          $ref: "#/components/schemas/TokensUsed"
        quota:
          $ref: "#/components/schemas/QuotaSnapshot"

    Form:
      type: object
      required: [title, questions]
      properties:
        title:
          type: string
          minLength: 1
          maxLength: 300
        description:
          type: string
          maxLength: 2000
        questions:
          type: array
          minItems: 1
          maxItems: 50
          items: { $ref: "#/components/schemas/Question" }

    Question:
      type: object
      required: [title, type]
      properties:
        title:
          type: string
          minLength: 1
          maxLength: 1000
        description:
          type: string
          maxLength: 2000
        required:
          type: boolean
          default: false
        type:
          type: string
          enum:
            - SHORT_ANSWER
            - PARAGRAPH
            - MULTIPLE_CHOICE
            - CHECKBOXES
            - DROPDOWN
            - LINEAR_SCALE
            - DATE
            - TIME
            - RATING
        options:
          type: array
          items: { type: string, minLength: 1, maxLength: 200 }
          minItems: 2
          maxItems: 20
          description: Required for MULTIPLE_CHOICE, CHECKBOXES, DROPDOWN.
        scaleMin:    { type: integer, minimum: 0, maximum: 1 }
        scaleMax:    { type: integer, minimum: 2, maximum: 10 }
        scaleMinLabel: { type: string, maxLength: 50 }
        scaleMaxLabel: { type: string, maxLength: 50 }
        ratingScale: { type: integer, enum: [3, 5, 10] }
      description: |
        The exact JSON shape AI must emit. Task 3 (AI Prompt Spec) defines
        per-type validation rules and the strict JSON Schema enforced
        server-side before responding to the client.

    TokensUsed:
      type: object
      properties:
        input:  { type: integer, minimum: 0 }
        output: { type: integer, minimum: 0 }

    QuotaSnapshot:
      type: object
      required: [tier, used, limit, resetsAt]
      properties:
        tier:     { type: string, enum: [free, premium] }
        used:     { type: integer, minimum: 0 }
        limit:    { type: integer, minimum: 0 }
        resetsAt: { type: string, format: date-time }

    # ---- Response: /user/status ----

    UserStatusResponse:
      type: object
      required:
        - isPremium
        - aiFreeUsed
        - aiFreeLimit
        - aiPremiumUsed
        - aiPremiumLimit
      properties:
        isPremium:        { type: boolean }
        aiFreeUsed:       { type: integer, minimum: 0 }
        aiFreeLimit:      { type: integer, minimum: 0 }
        freeResetsAt:
          type: string
          format: date-time
          nullable: true
          description: Null if user has never made a free generation.
        aiPremiumUsed:    { type: integer, minimum: 0 }
        aiPremiumLimit:   { type: integer, minimum: 0 }
        premiumResetsAt:
          type: string
          format: date-time
          nullable: true
          description: Null if user is not (and has never been) premium.
        gracePeriodUntil:
          type: string
          format: date-time
          nullable: true
          description: |
            Set when RC sent BILLING_ISSUE; cleared on RENEWAL or EXPIRATION.
            User retains premium access until this timestamp passes.

    # ---- Errors ----

    ErrorBody:
      type: object
      required: [code, message]
      properties:
        code:
          type: string
          description: Stable, machine-readable. See §6 catalog.
        message:
          type: string
          description: Human-readable. Wording may change without notice.
        details:
          type: object
          additionalProperties: true

    QuotaExceededDetails:
      allOf:
        - $ref: "#/components/schemas/ErrorBody"
        - type: object
          properties:
            details:
              type: object
              required: [tier, used, limit, resetsAt]
              properties:
                tier:     { type: string, enum: [free, premium] }
                used:     { type: integer }
                limit:    { type: integer }
                resetsAt: { type: string, format: date-time }

    IdempotencyConflictDetails:
      allOf:
        - $ref: "#/components/schemas/ErrorBody"
        - type: object
          properties:
            details:
              type: object
              properties:
                originalRequestHash: { type: string, description: SHA-256 hex of canonical body from first request }

  responses:
    BadRequest:
      description: Validation failure or malformed request
      content:
        application/json:
          schema: { $ref: "#/components/schemas/ErrorBody" }
    Unauthorized:
      description: Missing or invalid credentials
      content:
        application/json:
          schema: { $ref: "#/components/schemas/ErrorBody" }
    Forbidden:
      description: Authenticated but not allowed (premium gate, denylist)
      content:
        application/json:
          schema: { $ref: "#/components/schemas/ErrorBody" }
    IdempotencyConflict:
      description: Same Idempotency-Key reused with different body
      content:
        application/json:
          schema: { $ref: "#/components/schemas/IdempotencyConflictDetails" }
    QuotaExceeded:
      description: Tier quota exhausted
      content:
        application/json:
          schema: { $ref: "#/components/schemas/QuotaExceededDetails" }
    ServiceUnavailable:
      description: Transient backend failure or kill switch active
      content:
        application/json:
          schema: { $ref: "#/components/schemas/ErrorBody" }
```

---

## 4. Endpoint reference

The OpenAPI block above is the machine contract. The prose below covers behavior the schema can't express.

### 4.1 `POST /ai/generate`

**Purpose.** Generate a Google-Forms-shaped JSON form from user input. The Flutter client converts the response into Forms API `batchUpdate` calls to materialize the form in the user's Drive.

#### Input variants

| `inputType` | Allowed tier | Required fields | Limits |
|---|---|---|---|
| `text` | free + premium | `prompt` | ≤ 4000 chars |
| `pdf` | premium only | `fileBase64` | ≤ 5MB decoded |
| `youtube` | premium only | `youtubeUrl` | Single URL, must match YouTube pattern |
| `urls` | premium only | `urls` | 1–5 URLs, each fetched server-side and HTML-stripped |
| `book` | premium only | `fileBase64` | ≤ 5MB decoded; client-extracted chapter |

Free users sending any non-`text` `inputType` get **403 `premium_required`**. The schema does not enforce this — the server checks the user's tier after validating the request.

#### Idempotency contract

See §5 for the full state machine. Summary:

- `Idempotency-Key` is **required**. Missing → 400 `missing_idempotency_key`.
- Same key + same body → cached response (only successes are cached).
- Same key + different body → 409 `idempotency_conflict`.
- A retry of a *failed* attempt with the same key + same body re-runs the generation. Failures are not cached.

#### Server retry behavior

On Gemini 5xx, the server retries **once** after 500ms. If the second attempt also fails, returns 503 `gemini_unavailable`. Total time budget to the client: 30 seconds. After 30s the server cuts its own request and returns 503 `gemini_timeout`.

#### Quota burn

Quota is consumed **only on a successful 200 response with `status: "completed"`**. See "Quota Burn Semantics" in `Tasks.md` for the rationale. All failure modes (4xx, 503) leave the user's counter untouched but still write a row to `ai_generations` for debugging and abuse monitoring.

#### Forward-compatibility for async

The 200 response shape includes `status` so we can move generation to a queue without a v2 rev:

- Today (sync): `status: "completed"`, `form` present.
- Future (async): `status: "pending"`, no `form`. Client polls `GET /ai/generations/{generationId}` (added in a later phase) until it sees `completed`.

Clients should already store `generationId` and treat the `status` field as authoritative — not just check for `form`.

### 4.2 `POST /webhooks/revenuecat`

**Purpose.** Sync premium entitlement state from RevenueCat into our DB.

#### Processing order

1. **Verify HMAC** (raw body, constant-time compare). Fail → 401, no DB writes.
2. **Dedupe.** `INSERT INTO webhook_events (event_id, ...)` with `ON CONFLICT (event_id) DO NOTHING`. If 0 rows inserted, the event is a duplicate — return 200 immediately and skip user updates.
3. **Resolve user.** Match RC `app_user_id` → `users.google_sub`. If unknown, log and return 200 (don't 4xx — RC will retry forever; orphaned events are a config drift problem, not a transient one).
4. **Apply event.** Update `users` table per the event-type table in `Tasks.md` §RevenueCat Events. All updates are within a single transaction with the `webhook_events` insert.
5. **Return 200.** Body: `{ "received": true }`.

#### Failure modes

- HMAC mismatch → 401 `invalid_signature`.
- Malformed JSON → 400 `invalid_input`.
- DB write failure → 503 `database_unavailable`. **RC retries on 5xx** — by design, transient DB outages will heal automatically.
- Unknown event type → log warning, store the row, return 200. Don't break on new RC event types we haven't handled yet.

#### Sandbox

RC sends `environment: "SANDBOX"` on test events. In production, sandbox events are stored (so we can audit) but skip the `users` update. In staging, sandbox events update `users` normally.

### 4.3 `GET /user/status`

**Purpose.** Return enough state to render the AI Form Builder entry point ("2/3 remaining"), the paywall, and the editor's premium-gated controls.

#### Reset semantics

- `freeResetsAt` is set to `firstFreeUseAt + 30 days`. Rolling, **not** calendar-month. If the user has never used a free generation, this field is null and `aiFreeUsed=0`.
- `premiumResetsAt` is set from RC `RENEWAL` events. It does not roll on its own — it tracks the billing period.
- Both reset times are computed in advance and stored. The endpoint reads them; it does not compute them on the fly.

#### Auto-reset on read

If `freeResetsAt < now()`, the endpoint resets `aiFreeUsed=0` and rolls `freeResetsAt` to null **before** returning. This is the only place free quota resets — no nightly cron needed for that table.

(Premium quota resets only on RC `RENEWAL` webhook receipt, never on read.)

---

## 5. Idempotency contract

A single, complete state machine for `POST /ai/generate`. Pseudocode lives here so the implementation has one source of truth.

### 5.1 Cache scope

| What | Cached? |
|---|---|
| 200 success (status=completed) | **Yes**, indefinitely (until `ai_generations` row is purged at 60 days) |
| 503 / 5xx errors | **No** — retries re-run the generation |
| 400 / 401 / 403 / 409 | **No** — but never reach the cache anyway (client-side errors before processing) |

The cache key is `(user_id, idempotency_key)` enforced by the unique constraint on `ai_generations`.

### 5.2 Body hashing

The "is this the same request" check uses SHA-256 over the **canonicalized** JSON body:

1. Parse JSON → object.
2. Sort all object keys lexicographically, recursively.
3. Serialize with no whitespace.
4. SHA-256, hex-encoded.

Stored in `ai_generations.request_hash`. (Schema task 2 adds this column.)

### 5.3 Decision tree

```
on POST /ai/generate (auth, input validation, premium gate already passed):

  let key = headers["Idempotency-Key"]
  let hash = sha256(canonicalize(body))

  row = SELECT * FROM ai_generations
        WHERE user_id = $userId AND idempotency_key = $key
        FOR UPDATE   -- prevent racing retries

  if row is null:
    INSERT INTO ai_generations (user_id, idempotency_key, request_hash, status='processing', ...)
    proceed to generate (§5.4)

  else if row.request_hash != hash:
    return 409 idempotency_conflict
        details: { originalRequestHash: row.request_hash }

  else if row.status == 'success':
    return cached response (200 with row.output_json, row.generation_id)

  else if row.status == 'processing':
    return 409 idempotency_in_flight   -- rare race; client should backoff and retry

  else:  -- status in ('gemini_error', 'validation_error')
    UPDATE ai_generations SET status='processing', error_payload=null WHERE id = row.id
    proceed to generate (§5.4)
```

### 5.4 Post-generation write

```
on Gemini success + schema validation pass:
  UPDATE ai_generations SET
    status='success',
    output_json = $form,
    input_tokens, output_tokens, ...
  INCREMENT users.ai_free_used or ai_premium_used per tier
  return 200

on Gemini failure or validation failure:
  UPDATE ai_generations SET
    status='gemini_error' | 'validation_error',
    error_payload = $errorDetails
  -- do NOT increment user counter
  return 503 with appropriate code
```

### 5.5 Concurrency

The `FOR UPDATE` lock in §5.3 serializes concurrent retries on the same `(user_id, key)` pair. A second concurrent request with the same key blocks until the first completes, then sees the result and either returns the cache or proceeds appropriately. No double-charge, no double Gemini call.

---

## 6. Error code catalog

Every `code` value the server can emit. Stable across versions.

| HTTP | `code` | Where | Retryable | `details` includes | Meaning |
|---|---|---|---|---|---|
| 400 | `invalid_input` | any | No | per-field if available | Schema validation failed (missing/invalid fields, malformed JSON) |
| 400 | `missing_idempotency_key` | `/ai/generate` | No | — | Required header absent |
| 400 | `file_too_large` | `/ai/generate` (pdf/book) | No | `maxBytes`, `actualBytes` | Decoded base64 exceeds 5MB |
| 400 | `unsupported_input_type` | `/ai/generate` | No | `inputType` | `inputType` not in the enum |
| 400 | `url_fetch_failed` | `/ai/generate` (urls) | No | `url`, `reason` | URL unreachable, blocked, or wrong content-type. See Task 6 fetcher safeguards. |
| 400 | `youtube_unavailable` | `/ai/generate` (youtube) | No | `url` | YouTube rejected the URL (private/removed/region-locked) |
| 401 | `invalid_token` | bearer endpoints | No (re-auth) | — | Google ID token failed verification |
| 401 | `invalid_signature` | `/webhooks/revenuecat` | No | — | HMAC mismatch |
| 403 | `premium_required` | `/ai/generate` | No | `requiredEntitlement: "gfm_premium"`, `requestedInputType` | Free user requested PDF/YouTube/URLs/book |
| 403 | `user_blocked` | any | No | — | User on `USER_DENYLIST` env var |
| 409 | `idempotency_conflict` | `/ai/generate` | No (new key) | `originalRequestHash` | Same key, different body |
| 409 | `idempotency_in_flight` | `/ai/generate` | Yes (after 1s) | — | Concurrent retry; first request still processing |
| 429 | `quota_exceeded` | `/ai/generate` | At `resetsAt` | `tier`, `used`, `limit`, `resetsAt` | Tier quota exhausted |
| 429 | `rate_limited` | `/ai/generate` | At `retryAfter` | `retryAfter` (seconds) | Per-user, per-IP, or global rate limit hit (Task 6) |
| 503 | `gemini_unavailable` | `/ai/generate` | Yes | — | Gemini 5xx after 1 retry |
| 503 | `gemini_timeout` | `/ai/generate` | Yes | — | 30s budget exceeded |
| 503 | `validation_error` | `/ai/generate` | Yes | — | Gemini output failed schema after 1 repair attempt. Quota not consumed. |
| 503 | `service_disabled` | `/ai/generate` | Maybe later | — | `AI_GENERATION_DISABLED` kill switch active |
| 503 | `service_busy` | `/ai/generate` | Yes (after `Retry-After`) | `retryAfter` (seconds) | Global rate limit hit. Distinct from 429 `rate_limited` (per-user / per-IP). See `docs/rate-limiting-abuse.md` §4.1. |
| 503 | `daily_budget_exceeded` | `/ai/generate` | At UTC midnight | — | `MAX_DAILY_GEMINI_SPEND_USD` cap hit |
| 503 | `database_unavailable` | any | Yes | — | Postgres connection failed |

**Unknown codes:** clients must treat any unrecognized `code` as a generic error of the matching HTTP class. New codes will only ever be added — never repurposed.

---

## 7. Examples

### 7.1 `POST /ai/generate` — success (text input, free tier)

**Request**

```http
POST /ai/generate HTTP/1.1
Authorization: Bearer eyJhbGc...<google id token>
Content-Type: application/json
Idempotency-Key: 8b1c1f8a-2e4f-4e16-9f12-1a2b3c4d5e6f
X-Request-Id: dashboard-2026-05-08T14:32:11

{
  "inputType": "text",
  "prompt": "Customer feedback survey for a small bakery. Ask about visit frequency, favorite items, satisfaction, and any suggestions."
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
    "questions": [
      {
        "title": "How often do you visit our bakery?",
        "type": "MULTIPLE_CHOICE",
        "required": true,
        "options": ["First time", "Once a month", "Weekly", "Several times a week"]
      },
      {
        "title": "Which of these have you tried? (Select all that apply)",
        "type": "CHECKBOXES",
        "required": false,
        "options": ["Sourdough", "Croissants", "Cakes", "Cookies", "Coffee"]
      },
      {
        "title": "How satisfied were you with your visit?",
        "type": "LINEAR_SCALE",
        "required": true,
        "scaleMin": 1,
        "scaleMax": 5,
        "scaleMinLabel": "Very dissatisfied",
        "scaleMaxLabel": "Very satisfied"
      },
      {
        "title": "Any suggestions or comments?",
        "type": "PARAGRAPH",
        "required": false
      }
    ]
  },
  "tokensUsed": { "input": 218, "output": 412 },
  "quota": {
    "tier": "free",
    "used": 1,
    "limit": 3,
    "resetsAt": "2026-06-07T14:32:11.412Z"
  }
}
```

### 7.2 `POST /ai/generate` — premium gate (free user sends PDF)

**Request**

```http
POST /ai/generate HTTP/1.1
Authorization: Bearer <free-user-token>
Content-Type: application/json
Idempotency-Key: 11111111-2222-3333-4444-555555555555

{ "inputType": "pdf", "fileBase64": "JVBERi0xLjQKJa...." }
```

**Response — 403**

```json
{
  "code": "premium_required",
  "message": "PDF input is available for premium subscribers.",
  "details": {
    "requiredEntitlement": "gfm_premium",
    "requestedInputType": "pdf"
  }
}
```

### 7.3 `POST /ai/generate` — quota exceeded (free user, 4th attempt this period)

**Response — 429**

```json
{
  "code": "quota_exceeded",
  "message": "You've used all 3 free generations this month.",
  "details": {
    "tier": "free",
    "used": 3,
    "limit": 3,
    "resetsAt": "2026-06-07T14:32:11.412Z"
  }
}
```

### 7.4 `POST /ai/generate` — idempotency replay (cached success)

**Second request, same key, same body:** 200 with the same `generationId` and `form` as the first. `quota.used` reflects the count at the time of the original success — **not** re-incremented.

### 7.5 `POST /ai/generate` — idempotency conflict

**Request**

```http
POST /ai/generate
Idempotency-Key: 8b1c1f8a-2e4f-4e16-9f12-1a2b3c4d5e6f   # ← reused from §7.1
{ "inputType": "text", "prompt": "Different prompt entirely" }
```

**Response — 409**

```json
{
  "code": "idempotency_conflict",
  "message": "This Idempotency-Key was used with a different request body. Use a fresh key.",
  "details": {
    "originalRequestHash": "8f4c2b3e1a..."
  }
}
```

### 7.6 `POST /ai/generate` — Gemini transient failure

**Response — 503**

```json
{
  "code": "gemini_unavailable",
  "message": "The AI service is temporarily unavailable. Please try again in a moment."
}
```

Client retries with the **same** `Idempotency-Key` after 1s → 3s → 8s. If a retry succeeds, that's when quota burns.

### 7.7 `GET /user/status`

**Response — free user, never used AI**

```json
{
  "isPremium": false,
  "aiFreeUsed": 0,
  "aiFreeLimit": 3,
  "freeResetsAt": null,
  "aiPremiumUsed": 0,
  "aiPremiumLimit": 50,
  "premiumResetsAt": null,
  "gracePeriodUntil": null
}
```

**Response — premium user mid-period**

```json
{
  "isPremium": true,
  "aiFreeUsed": 0,
  "aiFreeLimit": 3,
  "freeResetsAt": null,
  "aiPremiumUsed": 12,
  "aiPremiumLimit": 50,
  "premiumResetsAt": "2026-06-01T00:00:00.000Z",
  "gracePeriodUntil": null
}
```

**Response — premium user in grace period (billing issue)**

```json
{
  "isPremium": true,
  "aiFreeUsed": 0,
  "aiFreeLimit": 3,
  "freeResetsAt": null,
  "aiPremiumUsed": 12,
  "aiPremiumLimit": 50,
  "premiumResetsAt": "2026-06-01T00:00:00.000Z",
  "gracePeriodUntil": "2026-05-24T00:00:00.000Z"
}
```

### 7.8 `POST /webhooks/revenuecat` — INITIAL_PURCHASE

**Request** (truncated, RC payload shape per RC docs)

```http
POST /webhooks/revenuecat
Authorization: 4a7b9c2e1f3d... (hex hmac of body)
Content-Type: application/json

{
  "event": {
    "id": "rc-evt-abc123",
    "type": "INITIAL_PURCHASE",
    "app_user_id": "google-sub-1234567890",
    "entitlement_ids": ["gfm_premium"],
    "expiration_at_ms": 1717200000000,
    "environment": "PRODUCTION"
  }
}
```

**Response — 200**

```json
{ "received": true }
```

(Same response on duplicate delivery — dedupe is silent.)

### 7.9 `POST /webhooks/revenuecat` — invalid signature

**Response — 401**

```json
{
  "code": "invalid_signature",
  "message": "Webhook signature verification failed."
}
```

No DB writes. RC will retry — fix the secret config.

---

## 8. Open questions / decisions deferred to later tasks

These are intentionally not pinned in this contract. Other tasks own them.

| Question | Owned by |
|---|---|
| Exact JSON schema enforced server-side on the AI's form output (per-question-type rules, repair vs reject) | Task 3 — AI Prompt Spec |
| RC `Authorization` header exact format (HMAC encoding, prefix, whitespace) — verify against current RC docs at implementation time | Task 5 — RevenueCat Webhook Map |
| Rate limit response headers (`X-RateLimit-Remaining`, `Retry-After`) | Task 6 — Rate Limiting & Abuse |
| URL fetcher specifics: SSRF guards, redirect cap, body cap, timeout values | Task 6 |
| `/health` admin endpoint shape (kill-switch state visibility) | Task 6 |
| Structured log field list and metric names | Task 7 — Observability |

---

## Appendix A — Acceptance criteria mapping

For Task 1 reviewer convenience. Each acceptance bullet → where it's satisfied in this doc.

| Acceptance criterion | Section |
|---|---|
| Every error has a `code` + `message` body | §2.5, §6 |
| `/ai/generate` request validates per-`inputType` | §3 (oneOf with discriminator), §4.1 |
| Idempotency-Key behavior documented | §5 |
| 429 includes `resetsAt`, `used`, `limit`, `tier` | §3 (`QuotaExceededDetails`), §6, §7.3 |
| `/user/status` shape | §3 (`UserStatusResponse`), §7.7 |
| `/ai/generate` 200 includes `generationId` + `status` | §3 (`GenerateResponse`), §4.1 |
| Errors do not include `generationId` | §3 (`ErrorBody`), §4.1, §7.2/7.3/7.5/7.6 |
