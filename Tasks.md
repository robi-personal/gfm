# Tasks

## 1. Weekly + monthly spend caps (rolling windows)

### 1a. Env vars — `haiku`
- Add `MAX_WEEKLY_GEMINI_SPEND_USD`, `MAX_MONTHLY_GEMINI_SPEND_USD` (global) to `env.ts`
- Add `MAX_USER_WEEKLY_GEMINI_USD`, `MAX_USER_MONTHLY_GEMINI_USD` (per-user) to `env.ts`

### 1b. Repository — `sonnet`
- Replace `getGlobalDailySpendUsd()` with `getGlobalSpendUsd(sinceMs: number)` in `AiGenerationRepository` interface and `PgAiGenerationRepository`
- Replace `getTotalSpendUsd(userId, sinceMs)` — already rolling, no change needed
- Update `kill-switch.middleware.ts` to call `getGlobalSpendUsd` with daily / 7d / 30d windows

### 1c. Kill-switch middleware — `sonnet`
- Extend `dailyBudgetMiddleware` (or add `weeklyBudgetMiddleware` / `monthlyBudgetMiddleware`) to check all three global caps in sequence
- Extend `perUserBudgetMiddleware` to check all three per-user caps in sequence
- Add separate in-process caches for weekly and monthly global spend (TTL: 60s each)

### 1d. Metrics — `haiku`
- Update `geminiSpendUsdToday` gauge or add `geminiSpendUsd` gauge with `window` label (`daily`, `weekly`, `monthly`)

## 2. Admin panel

### 2a. DB migration + ConfigService — `opus`
- `migrations/002_server_config.sql` — `server_config` table (key, value, updated_at)
- `src/domain/repositories/config.repository.ts` — interface
- `src/infrastructure/db/repositories/pg-config.repository.ts` — Postgres impl
- `src/config/config-service.ts` — loads from DB at boot, exposes `reload()`, merges with `env` defaults, patches rate limiter `.points` on refresh. `PATCH /admin/config` calls `reload()` after writing — no polling. (If we ever run >1 backend process, add Redis pub/sub on a `config:changed` channel then.)

### 2b. Admin API — `sonnet`
- Add `ADMIN_TOKEN` to `env.ts`
- `src/presentation/middleware/admin-auth.middleware.ts` — bearer token check
- `src/presentation/routes/admin.routes.ts` — `GET /admin/config`, `PATCH /admin/config`
- Wire admin router in `app.ts`

### 2c. Admin UI — `sonnet`
- `GET /admin` serves a vanilla HTML page (no build step)
- Sections: Kill switches, Budget caps (with current spend readout), Rate limits
- Auth: prompts for `ADMIN_TOKEN`, stores in `sessionStorage`

### 2d. Middleware refactor — `sonnet`
- Kill-switch and budget-cap middleware read from `ConfigService` instead of `env` directly
- Rate limiters: `ConfigService.onRefresh()` patches each limiter's `.points`

## 3. YouTube minute cap — `sonnet`
- Add `youtube_minutes_used` and `youtube_minutes_reset_at` columns to users table
- Add `YOUTUBE_API_KEY` to env and `src/config/env.ts`
- Create `src/ai/youtube-duration.ts` — fetch duration from YouTube Data API v3, parse ISO 8601 → minutes (ceil)
- Create `src/presentation/middleware/youtube-minutes.middleware.ts` — check monthly cap, attach `req.videoDurationMinutes`, reject with `youtube_minutes_exceeded`
- Add `getYoutubeMinutesUsed`, `incrementYoutubeMinutes`, `resetYoutubeMinutesIfNeeded` to user repository
- Wire middleware in `ai.routes.ts`, deduct minutes after successful generation
- Handle `youtube_minutes_exceeded` error in Flutter
- Add `youtubeMinutesUsed` and `youtubeMinutesLimit` to `getQuotaSnapshot()` response
- Add `youtubeMinutesUsed` and `youtubeMinutesLimit` to `QuotaSnapshot` entity in Flutter
- Show remaining YouTube minutes below the URL field when YouTube tab is selected
