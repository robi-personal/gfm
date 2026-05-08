# Phase 2 — AI Middleware Implementation

Backend: Node.js + Express + TypeScript, Dockerized.
Spec docs in `docs/` — read the relevant doc before starting each task.
Work in order; each task builds on the previous.

---

## Tasks

| # | Task | Model | Depends on | Status |
|---|------|-------|------------|--------|
| 1 | Project scaffold (TypeScript, Express, directory structure) | **Sonnet 4.6** | — | ✅ Done |
| 2 | Dockerfile + Docker Compose (app, postgres, redis, nginx) | **Sonnet 4.6** | 1 | ⬜ Pending |
| 3 | Database — connection pool + migration runner | **Sonnet 4.6** | 2 | ⬜ Pending |
| 4 | Core middleware (requestId, pino logging, body parser, trust proxy) | **Sonnet 4.6** | 1 | ⬜ Pending |
| 5 | Auth — Google ID token verification | **Sonnet 4.6** | 4 | ⬜ Pending |
| 6 | Kill switches (env var parsing + middleware) | **Sonnet 4.6** | 4 | ⬜ Pending |
| 7 | Rate limiting (Redis + rate-limiter-flexible, all buckets) | **Sonnet 4.6** | 3, 5 | ⬜ Pending |
| 8 | Cost circuit breakers (per-user 24h + global daily) | **Sonnet 4.6** | 3, 5 | ⬜ Pending |
| 9 | `GET /user/status` | **Sonnet 4.6** | 3, 5 | ⬜ Pending |
| 10 | RevenueCat webhook (HMAC, dedupe, all 7 event handlers) | **Sonnet 4.6** | 3 | ⬜ Pending |
| 11 | URL fetcher (SSRF guards, redirects, content-type, timeouts) | **Opus 4.7** | 4 | ⬜ Pending |
| 12 | Gemini client (structured output, retry, 30s timeout) | **Sonnet 4.6** | 4 | ⬜ Pending |
| 13 | Zod validation + repair turn (all 9 question types, fallback detection) | **Sonnet 4.6** | 12 | ⬜ Pending |
| 14 | `POST /ai/generate` (full pipeline) | **Opus 4.7** | 3, 5, 6, 7, 8, 11, 12, 13 | ⬜ Pending |
| 15 | `/health` + `/metrics` endpoints | **Sonnet 4.6** | 3, 4 | ⬜ Pending |
| 16 | Observability — pino fields, prom-client instruments, Sentry | **Sonnet 4.6** | 4, 14, 15 | ⬜ Pending |
| 17 | Nginx reverse proxy config (TLS, body size, real IP) | **Sonnet 4.6** | 2 | ⬜ Pending |
| 18 | Production compose + secrets + deployment runbook | **Sonnet 4.6** | 2, 17 | ⬜ Pending |

### Model rationale
- **Opus 4.7** for tasks where a mistake is exploitable or hard to reverse: URL fetcher (SSRF defense is subtle — DNS rebinding, per-hop IP rechecks), `/ai/generate` pipeline (quota burn semantics, idempotency state machine, and all error codes wired together — bugs here affect every user).
- **Sonnet 4.6** for everything else — all design decisions are fully specified in the spec docs; implementation is mechanical.

---

## Spec docs (reference per task)

| Task(s) | Spec doc |
|---------|----------|
| 3, 8, 9, 10 | `docs/db/migrations/001_init.sql` |
| 5, 9, 10, 14 | `docs/api-contract.md` |
| 6, 7, 8, 11, 17 | `docs/rate-limiting-abuse.md` |
| 10 | `docs/revenuecat-webhook-map.md` |
| 12, 13, 14 | `docs/ai-prompt-spec.md` |
| 14 | `docs/feature-spec-flutter.md` (for error codes the Flutter client expects) |
| 15, 16 | `docs/observability.md` |

---

## Architecture decisions (carry-forward)

- **Runtime:** Node.js + Express + TypeScript
- **Database:** PostgreSQL (Docker service)
- **Cache / rate-limit store:** Redis (Docker service)
- **Reverse proxy:** Nginx (Docker service) + Let's Encrypt TLS
- **AI model:** Gemini 2.0 Flash
- **Process management:** Docker (replaces PM2)
- **Backend directory:** `gfm_mw/`
- **Entitlement identifier:** `gfm_premium`
- App never calls Gemini directly — all AI through this middleware
