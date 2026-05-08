# Phase 2 — AI Form Builder

Generate these documents **before writing any code**. Work through them in order — each builds on the previous. After each task, review against its acceptance criteria before moving on.

---

## Tasks

| # | Document | Model | Depends on | Status |
|---|----------|-------|------------|--------|
| 1 | API Contract | **Opus 4.7** | — | ✅ Done — `docs/api-contract.md` |
| 2 | Database Schema (SQL migrations) | **Sonnet 4.6** | 1 | ✅ Done — `docs/db/migrations/001_init.sql`, `docs/db/scripts/cleanup_expired_generations.sql` |
| 3 | AI Prompt Spec | **Opus 4.7** | 1 | ✅ Done — `docs/ai-prompt-spec.md` |
| 4 | Feature Spec (Flutter UI/flows) | **Sonnet 4.6** | 1 | ✅ Done — `docs/feature-spec-flutter.md` |
| 5 | RevenueCat Webhook Map | **Sonnet 4.6** | 2 | ✅ Done — `docs/revenuecat-webhook-map.md` |
| 6 | Rate Limiting & Abuse Strategy | **Opus 4.7** | 1 | ✅ Done — `docs/rate-limiting-abuse.md` |
| 7 | Observability (logs, metrics, error tracking) | **Sonnet 4.6** | 1, 2 | ✅ Done — `docs/observability.md` |

### Model rationale
- **Opus 4.7** for tasks where wrong choices are expensive or hard to reverse: API contract (clients depend on it), prompt design (drives output quality of every generation), security/abuse (exploitable mistakes).
- **Sonnet 4.6** for well-trodden mechanical work: SQL migrations, UI flows, webhook handlers, standard observability patterns. Faster + cheaper, no quality gap on these.
- **Haiku 4.5** not recommended for any of these — they're all spec-quality work, not throwaway scripts.

---

## Per-task scope and acceptance criteria

> Use these as the brief when starting each task, and as the checklist when reviewing the output.

### Task 1 — API Contract  *(Opus 4.7)*
**Scope:** Full OpenAPI 3.1 spec (or markdown equivalent) for `/ai/generate`, `/webhooks/revenuecat`, `/user/status`. Includes request/response schemas, all error codes, headers (auth, idempotency), example payloads.
**Accept when:**
- [ ] Every error in the draft (400/401/403/409/429/503) has a documented response body shape with `code` and `message`
- [ ] `/ai/generate` request schema validates each `inputType` variant (text vs pdf vs youtube vs urls)
- [ ] Idempotency-Key behavior documented (replay returns cached response, conflict returns 409). Only **successful** responses are cached; failures are not replayed (a retry re-runs the generation).
- [ ] Quota-exceeded 429 body includes `resetsAt`, `used`, `limit`, and `tier` — saves the client a `/user/status` round-trip when rendering the upsell modal
- [ ] `/user/status` response matches the shape in this doc
- [ ] `/ai/generate` 200 response includes `generationId` and a `status` field — future-proofs for async without forcing it now (no v2 needed when we move to a queue)
- [ ] Error responses do **not** include `generationId`. Rationale: failures don't burn quota (see "Quota Burn Semantics" in Decisions Made), so there's no user-facing receipt to surface.

### Task 2 — Database Schema  *(Sonnet 4.6)*
**Scope:** Real SQL migration files (`001_init.sql`, etc.) for `users`, `webhook_events`, `ai_generations`. Indexes, FKs, NOT NULL constraints, default values. Cleanup job for expired generation rows.
**Accept when:**
- [ ] `users.google_sub` has unique index; `email` does not
- [ ] `webhook_events.event_id` is PK (idempotency)
- [ ] `ai_generations` has `UNIQUE (user_id, idempotency_key)` and unique index on `generation_id`
- [ ] `ai_generations.output_json` is JSONB; row written on success and on failure (with `error_payload`) — debug gold
- [ ] `ai_generations.expires_at` set to `created_at + 60 days`; nightly cron `DELETE FROM ai_generations WHERE expires_at < now()`
- [ ] Index on `ai_generations.expires_at` so cleanup is cheap
- [ ] Indexes on FK columns and on any column used in WHERE clauses (e.g., `users.google_sub`, `ai_generations.user_id + created_at`)
- [ ] Raw uploads (PDF bytes, fetched HTML) are **never** persisted — only `input_size`, `input_type`, and a hash if needed
- [ ] Migrations run cleanly on empty Postgres and are reversible (`DOWN` provided)

### Task 3 — AI Prompt Spec  *(Opus 4.7)*
**Scope:** Gemini system prompt + structured output JSON schema for the Forms object. Few-shot examples for each input type. Failure modes documented (e.g., what to return when input is unintelligible). **Server-side validation pipeline** with one repair attempt before returning to the client.
**Accept when:**
- [ ] System prompt produces output matching the Google Forms `batchUpdate` item shape (no unsupported types like `FileUploadQuestion`)
- [ ] Strict JSON Schema written for the form output; validated server-side with **Zod** (or Ajv) before any Forms API call
- [ ] On validation failure: 1 repair attempt — feed the validator error back to Gemini with a "fix this" instruction, then re-validate. If 2nd attempt fails → `validation_error` status logged with both attempts in `error_payload`, client gets 503. **Quota is not burned** (see "Quota Burn Semantics" in Decisions Made); abuse exposure is bounded by Task 6 rate limits + circuit breakers.
- [ ] Validation rejects (does not auto-repair): unsupported question types, >50 questions, missing required fields. These are fatal — client gets 503 `validation_error`. Failure row is still written to `ai_generations` for debug; quota counter is not incremented.
- [ ] Validation auto-repairs: malformed enum casing, missing optional fields, trailing commas — handled in code, not via re-prompt.
- [ ] At least 2 few-shot examples per input type (text, pdf, youtube, urls)
- [ ] Question count target documented (10–15) with override behavior
- [ ] Tested manually against 5+ real prompts before signoff, including 1 deliberately adversarial input

### Task 4 — Feature Spec (Flutter)  *(Sonnet 4.6)*
**Scope:** Screen-by-screen UI spec for AI Form Builder. State machine for input → generating → preview → create-form. Empty/error/loading states. Premium gate triggers.
**Accept when:**
- [ ] Free vs premium UI explicitly differentiated (input type selector hidden for free)
- [ ] Quota counter visible on entry ("2/3 remaining")
- [ ] Every API error from Task 1 has a matching UI state
- [ ] Paywall trigger paths enumerated (quota exhausted, premium-only input type)
- [ ] Loading state handles 30s Gemini timeout

### Task 5 — RevenueCat Webhook Map  *(Sonnet 4.6)*
**Scope:** Handler pseudo-code for each event type. Edge cases: out-of-order events, duplicate event IDs, sandbox vs prod, transfer between accounts.
**Accept when:**
- [ ] Each of 7 event types has a handler block with explicit DB writes
- [ ] Dedupe-on-`event_id` shown as the first step
- [ ] `BILLING_ISSUE` → `EXPIRATION` flow walks through grace period correctly
- [ ] Out-of-order delivery (e.g., RENEWAL arrives before INITIAL_PURCHASE) handled
- [ ] Sandbox events identified and either ignored in prod or routed separately

### Task 6 — Rate Limiting, Abuse & Kill Switches  *(Opus 4.7)*
**Scope:** Per-user, per-IP, and global rate limits. Bot/scraper defenses. Token-cost guards. Suspicious-pattern detection. **Operational kill switches and cost circuit breakers.**
**Accept when:**
- [ ] Limits specified for `/ai/generate` (per user, per IP, global)
- [ ] Maximum request body size enforced at Nginx + Express
- [ ] PDF/URL fetch budgets capped (no SSRF, no recursive fetch)
- [ ] URL fetcher safeguards: blocks RFC1918 + link-local + loopback (resolve DNS first, then check IP); follows max 3 redirects with private-IP check on each hop; `Content-Type` allowlist (`text/html`, `text/plain`, `application/xhtml+xml`); 5s connect + 10s total timeout; 5MB body cap; user-agent identifies the service
- [ ] Cost-per-user circuit breaker if Gemini spend exceeds threshold (computed from `ai_generations.input_tokens + output_tokens` rolling 24h, **including failed rows** — failures don't burn user quota but they still cost us money)
- [ ] Per-user attempt rate limit (e.g., 10/hour) sized to bound the cost of users whose generations always fail validation. Since validation failures no longer consume quota, rate limits are the primary defense against grind-attacks.
- [ ] **Kill switches** wired into config (env vars):
  - `AI_GENERATION_DISABLED=true` → all `/ai/generate` returns 503 with `code=service_disabled`
  - `MAX_DAILY_GEMINI_SPEND_USD=10` → tracked from token logs; when exceeded, 503 with `code=daily_budget_exceeded`
  - `USER_DENYLIST=sub1,sub2,sub3` → comma-separated `google_sub` values; matched users get 403
- [ ] Kill switch state visible in `/health` endpoint (admin-only) so on-call can check without DB access
- [ ] Documented runbook: how to flip each switch in production (PM2 reload vs hot reload)

### Task 7 — Observability  *(Sonnet 4.6)*
**Scope:** Structured logging fields, metrics list, error-tracking integration, dashboards.
**Accept when:**
- [ ] Every request logs: `request_id`, `user_id`, `route`, `status`, `latency_ms`, `gemini_input_tokens`, `gemini_output_tokens`
- [ ] Metrics defined: requests/min, p50/p95/p99 latency, Gemini error rate, quota-exceeded rate, RC webhook lag
- [ ] Error tracker (Sentry or similar) captures unhandled errors with `user_id` tag
- [ ] Alert thresholds proposed (e.g., Gemini error rate >5% for 5min)

---

## Decisions Made

### Architecture
- Middleware: **Node.js + Express** on **Hostinger KVM2 VPS** (2 vCPU, 8GB RAM, 100GB NVMe)
- Database: **PostgreSQL** (on same VPS)
- Reverse proxy: **Nginx** + **Let's Encrypt SSL** (domain required — iOS ATS blocks plain HTTP)
- Process manager: **PM2**
- The Flutter app **never calls Gemini directly** — all AI goes through middleware

### AI Model
- **Gemini 2.0 Flash** (free tier for MVP, upgrade to paid before public launch)
- Free tier: 1,500 requests/day, 15 RPM — sufficient for MVP
- Paid tier: ~$0.075 input / $0.30 output per million tokens (cheaper than Claude Haiku)
- Native PDF input + native YouTube URL support — no manual extraction needed on free tier
- **Do NOT rotate multiple API keys** — violates Google ToS. Upgrade to paid instead.

### Quota Model
| Tier | AI Form Generations | Input Types |
|------|-------------------|-------------|
| Free | 3 / month (rolling, resets on `free_month_reset_at`) | Text prompt only |
| Premium (`gfm_premium`) | 50 / month (resets on RC `RENEWAL`) | Text + PDF + YouTube URL + Website/blog links |

> Decision: free quota is monthly, not lifetime. Lifetime caps drive harder conversion but also drive uninstalls before users can fairly evaluate the feature. Revisit after 30 days of usage data.

### Quota Burn Semantics

**Quota is consumed only on successful generation.** A success is: Gemini returned valid JSON, schema validation passed (auto-repair counts), and the client received a `form` object.

**Does NOT burn quota:**
- 4xx errors (bad input, auth, premium gate) — never reached Gemini
- 503 `gemini_unavailable` — Gemini 5xx after 1 retry
- 503 `validation_error` — Gemini output failed schema after 1 repair attempt
- Idempotency replay of a previously cached success (already burned on first call)

**Rationale:** without customer service, "we charged you for nothing" is a one-way door to uninstall. Quota is the user-facing promise ("you bought 3, you get 3"); it should not be coupled to our tooling's reliability. Cost exposure from honest failures is negligible (~$0.0025/user/month at 5% Gemini failure rate). Cost exposure from grind-attacks is bounded by Task 6 rate limits + circuit breakers — that's the right place to handle abuse.

**Bookkeeping:** failed attempts still write a row to `ai_generations` (with `status='gemini_error'` or `'validation_error'` and full `error_payload`) so we can debug from logs and watch failure rates. They just don't increment `ai_free_used` / `ai_premium_used`.

**Idempotency cache scope:** only successful responses are cached for replay. Retrying a failure re-runs the generation; if it succeeds the second time, *that* call burns quota.

### Authentication
- App sends **Google ID token** in `Authorization: Bearer <token>` header
- Middleware verifies token with Google's public API — no separate auth system needed
- User identity = `sub` claim from ID token (stable). `email` is denormalized for display only — it can change.

### Subscription Sync
- RevenueCat sends webhook events to Node backend
- Backend updates `is_premium` flag in PostgreSQL on subscription events
- Entitlement identifier: `gfm_premium`
- Webhooks are deduped by `event.id` via `webhook_events` table (RC retries on 5xx)
- Signature verification: HMAC-SHA256 of raw body using shared secret in `Authorization` header (per RC docs)

### Input Types Detail
| Input | Free | Premium | Notes |
|-------|------|---------|-------|
| Text prompt | ✅ | ✅ | Simple text description of desired form |
| PDF upload | ❌ | ✅ | Up to 5MB, send natively to Gemini |
| YouTube URL | ❌ | ✅ | Gemini handles natively — no transcript fetch needed |
| Website/blog links | ❌ | ✅ | Multiple links, fetch + strip HTML, cap at ~2500 tokens/link (most blog posts run 2-4k) |
| Book by chapter | ❌ | ✅ | Client extracts chapter (by heading) and uploads as PDF ≤ 5MB. Full books exceed 5MB — extraction must happen on-device before upload. |

### Token Budget (Premium inputs)
- Gemini 2.0 Flash has 1M token context window — no truncation needed for most inputs
- For free text: keep prompt under 500 tokens
- System prompt: ~200 tokens
- Expected output per generation: ~800 tokens (10-15 questions)

### Consumable Top-ups
- Decided **against** pay-per-pack consumables (Apple 30% cut, complex IAP setup)
- Use tiered monthly plans instead if higher quotas needed

---

## Database Schema (Draft)

```sql
users
  id                    SERIAL PRIMARY KEY
  google_sub            TEXT UNIQUE NOT NULL    -- stable identity from ID token `sub` claim
  email                 TEXT NOT NULL           -- denormalized for display, NOT unique (users change emails)
  created_at            TIMESTAMPTZ DEFAULT NOW()
  ai_free_used          INTEGER DEFAULT 0       -- free quota used this period (max 3)
  ai_premium_used       INTEGER DEFAULT 0       -- premium quota used this period (max 50)
  free_month_reset_at   TIMESTAMPTZ             -- when ai_free_used resets (rolling 30 days from first use)
  premium_reset_at      TIMESTAMPTZ             -- when ai_premium_used resets (driven by RC RENEWAL)
  is_premium            BOOLEAN DEFAULT FALSE   -- synced from RC webhook
  grace_period_until    TIMESTAMPTZ             -- billing-issue grace period expiry (nullable)

webhook_events
  event_id        TEXT PRIMARY KEY              -- RC event.id, dedupes retries
  event_type      TEXT NOT NULL
  user_id         INTEGER REFERENCES users(id)
  raw_payload     JSONB NOT NULL
  processed_at    TIMESTAMPTZ DEFAULT NOW()

ai_generations
  id              SERIAL PRIMARY KEY
  generation_id   TEXT UNIQUE NOT NULL          -- public ID returned to client (UUID); future async-friendly
  user_id         INTEGER REFERENCES users(id) NOT NULL
  idempotency_key TEXT NOT NULL                 -- client-supplied, dedupes retries
  input_type      TEXT NOT NULL                 -- 'text' | 'pdf' | 'youtube' | 'urls' | 'book'
  input_size      INTEGER                       -- bytes or token count
  input_tokens    INTEGER
  output_tokens   INTEGER
  output_json     JSONB                         -- generated form JSON; nullable for non-success rows
  error_payload   JSONB                         -- error details for non-success rows (Gemini error, validation failures)
  status          TEXT NOT NULL                 -- 'success' | 'gemini_error' | 'validation_error'
  created_at      TIMESTAMPTZ DEFAULT NOW()
  expires_at      TIMESTAMPTZ NOT NULL          -- created_at + 60 days; cleanup job purges rows past this
  UNIQUE (user_id, idempotency_key)
```

---

## API Endpoints (Draft)

```
POST /ai/generate
  Auth: Google ID token
  Headers: Idempotency-Key: <uuid>   (required — dedupes client retries on flaky network)
  Body: { inputType, prompt?, fileBase64?, youtubeUrl?, urls[] }
  Response (sync, current MVP): {
    generationId,                   // UUID — clients should store this even if they ignore it
    status: "completed",
    form: { title, description, questions[] }
  }
  Future async (no client breakage): same shape, status may be "pending" with no `form` field;
    client polls GET /ai/generations/:generationId until status="completed".
  Errors:
    400 — validation (missing/invalid input, file too large, unsupported inputType)
    401 — invalid/expired token
    403 — input type requires premium
    409 — idempotency-key reuse with different payload
    429 — quota exceeded (body includes resetsAt)
    503 — Gemini unavailable (server retried once, gave up) OR AI_GENERATION_DISABLED kill switch active
  Server behavior: 1 retry with 500ms backoff on Gemini 5xx; 30s total timeout to client.

POST /webhooks/revenuecat
  Auth: HMAC-SHA256(rawBody, RC_WEBHOOK_SECRET) in Authorization header
  Body: RC event payload
  Action: insert into webhook_events (dedupe on event.id), then update users
  Response: 200 always after dedupe insert (RC retries on 5xx)

GET /user/status
  Auth: Google ID token
  Response: {
    isPremium,
    aiFreeUsed, aiFreeLimit, freeResetsAt,
    aiPremiumUsed, aiPremiumLimit, premiumResetsAt,
    gracePeriodUntil
  }
```

---

## RevenueCat Events to Handle

| Event | Action |
|-------|--------|
| `INITIAL_PURCHASE` | Set `is_premium=true`, `ai_premium_used=0`, set `premium_reset_at` |
| `RENEWAL` | Reset `ai_premium_used=0`, update `premium_reset_at`, clear `grace_period_until` |
| `CANCELLATION` | No immediate action (still premium until `EXPIRATION`) |
| `EXPIRATION` | Set `is_premium=false`, clear `grace_period_until` |
| `BILLING_ISSUE` | Keep `is_premium=true`, set `grace_period_until = now() + 16 days` (matches Apple billing retry window). Revoke on `EXPIRATION`. |
| `REFUND` | Set `is_premium=false` |
| `PRODUCT_CHANGE` | Update entitlement; no quota reset |

All events processed idempotently via `webhook_events.event_id` PK.

---

## Flutter Side (Phase 2 App Changes)

- New screen: **AI Form Builder** — accessible from dashboard
- Free users: text prompt input only, counter showing "2/3 remaining"
- Premium users: input type selector (text / PDF / YouTube / website)
- On success: created form JSON → call Forms API to create real form → open in editor
- Premium gate: if free quota exhausted → open `PaywallPage`
- Error states: quota exceeded, Gemini unavailable, invalid input

---

## Forms API Constraints (carry-forward from Phase 1)

- Cannot pass items in `forms.create` — create blank form first, then `batchUpdate` all items
- Cannot create `FileUploadQuestion` via API — read-only
- Max practical batch: ~50 questions
- After AI generates JSON → validate question types against supported API types before sending
