# Mobile Google Forms Companion — Claude Code Instructions

Before starting any task, read:
- `SESSION_CONTEXT.md` — build progress, architecture decisions, fixed bugs, next steps
- Relevant sections of `docs/` — kept up to date with the current app + middleware:
  - `docs/PRD.md` — product overview, scope, hard limits
  - `docs/TDD.md` — Flutter + middleware architecture, file structure, deployment
  - `docs/api-contract.md` — HTTP contract between app, middleware, RevenueCat, Pub/Sub
  - `docs/purchase-flow.md` — paywall → RC → middleware → `/user/status` trace
  - `docs/revenuecat-webhook-map.md` — per-event handler semantics
  - `docs/ai-prompt-spec.md` — Gemini prompt + repair pipeline
  - `docs/rate-limiting-abuse.md` — limits, kill switches, SSRF defenses
  - `docs/observability.md` — logs, metrics, alerts
- Only read what the current task needs.
