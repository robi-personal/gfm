import { Request, Response, NextFunction } from "express";
import { env } from "../../config/env";
import { pool } from "../../infrastructure/db/postgres";
import { PgAiGenerationRepository } from "../../infrastructure/db/repositories/pg-ai-generation.repository";
import {
  killSwitchTrippedTotal,
  costBreakerTrippedTotal,
  geminiSpendUsd,
} from "../../infrastructure/metrics";

// ── 1. AI_GENERATION_DISABLED ─────────────────────────────────────────────────
// Runs before auth on /ai/* paths. Pure env var check — no DB, no tokens.
export function aiGenerationDisabledMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  if (env.AI_GENERATION_DISABLED) {
    req.log.warn({ path: req.path }, "kill_switch_tripped_service_disabled");
    killSwitchTrippedTotal.inc({ which: "ai_generation_disabled" });
    res.status(503).json({
      code: "service_disabled",
      message: "AI generation is temporarily disabled. Please try again later.",
    });
    return;
  }
  next();
}

// ── 2. USER_DENYLIST ──────────────────────────────────────────────────────────
// Runs after auth. O(1) Set lookup on req.user.googleSub.
export function denylistMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  const sub = req.user?.googleSub;
  if (sub && env.USER_DENYLIST.has(sub)) {
    req.log.warn({ googleSub: sub, user_id: req.user?.id }, "kill_switch_tripped_user_blocked");
    killSwitchTrippedTotal.inc({ which: "user_blocked" });
    res.status(403).json({
      code: "user_blocked",
      message: "Your account has been suspended.",
    });
    return;
  }
  next();
}

// ── 3. Per-user cost circuit breaker (daily / weekly / monthly) ───────────────
// Runs after auth on /ai/generate. Three parallel DB queries per request.
// Includes both successful and failed rows per rate-limiting-abuse.md §8.1.
export async function perUserBudgetMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const now = Date.now();
  const MS_PER_DAY = 24 * 60 * 60 * 1_000;

  const caps = [
    { window: "daily",   sinceMs: now - MS_PER_DAY,       cap: env.MAX_USER_DAILY_GEMINI_USD },
    { window: "weekly",  sinceMs: now - 7 * MS_PER_DAY,   cap: env.MAX_USER_WEEKLY_GEMINI_USD },
    { window: "monthly", sinceMs: now - 30 * MS_PER_DAY,  cap: env.MAX_USER_MONTHLY_GEMINI_USD },
  ].filter((c) => c.cap > 0);

  if (caps.length === 0) {
    next();
    return;
  }

  try {
    const repo = new PgAiGenerationRepository(pool);
    const spends = await Promise.all(caps.map((c) => repo.getTotalSpendUsd(req.user!.id, c.sinceMs)));

    for (let i = 0; i < caps.length; i++) {
      const { window, cap } = caps[i];
      const spend = spends[i];
      if (spend >= cap) {
        req.log.warn(
          { userId: req.user!.id, window, spendUsd: spend, capUsd: cap },
          "cost_breaker_tripped_per_user",
        );
        costBreakerTrippedTotal.inc({ scope: "per-user" });
        res.status(503).json({
          code: `${window}_budget_exceeded`,
          message: `You have reached the ${window} usage limit. Please try again later.`,
        });
        return;
      }
    }

    next();
  } catch (err) {
    req.log.error({ err }, "per_user_budget_check_failed");
    next(); // fail open — don't block everyone when DB is slow
  }
}

// ── 4. Global spend caps (daily / weekly / monthly) ───────────────────────────
// Runs after auth. Each window has a separate 60s in-process cache.
// See rate-limiting-abuse.md §8.2.
const MS_PER_DAY = 24 * 60 * 60 * 1_000;

type SpendCache = { value: number; fetchedAt: number };
let globalDailyCache:   SpendCache = { value: 0, fetchedAt: 0 };
let globalWeeklyCache:  SpendCache = { value: 0, fetchedAt: 0 };
let globalMonthlyCache: SpendCache = { value: 0, fetchedAt: 0 };

const TTL_MS = 60_000;

async function refreshIfStale(
  cache: SpendCache,
  sinceMs: number,
  repo: PgAiGenerationRepository,
): Promise<SpendCache> {
  if (Date.now() - cache.fetchedAt < TTL_MS) return cache;
  const value = await repo.getGlobalSpendUsd(sinceMs);
  return { value, fetchedAt: Date.now() };
}

export async function globalBudgetMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const now = Date.now();

  const windows = [
    { label: "daily",   sinceMs: now - MS_PER_DAY,       cap: env.MAX_DAILY_GEMINI_SPEND_USD,   cache: globalDailyCache,   set: (c: SpendCache) => { globalDailyCache = c; } },
    { label: "weekly",  sinceMs: now - 7 * MS_PER_DAY,   cap: env.MAX_WEEKLY_GEMINI_SPEND_USD,  cache: globalWeeklyCache,  set: (c: SpendCache) => { globalWeeklyCache = c; } },
    { label: "monthly", sinceMs: now - 30 * MS_PER_DAY,  cap: env.MAX_MONTHLY_GEMINI_SPEND_USD, cache: globalMonthlyCache, set: (c: SpendCache) => { globalMonthlyCache = c; } },
  ].filter((w) => w.cap > 0);

  if (windows.length === 0) {
    next();
    return;
  }

  try {
    const repo = new PgAiGenerationRepository(pool);

    for (const w of windows) {
      const fresh = await refreshIfStale(w.cache, w.sinceMs, repo);
      w.set(fresh);
      geminiSpendUsd.labels(w.label).set(fresh.value);

      if (fresh.value >= w.cap) {
        req.log.warn(
          { window: w.label, spendUsd: fresh.value, capUsd: w.cap },
          "kill_switch_tripped_global_budget_exceeded",
        );
        killSwitchTrippedTotal.inc({ which: `${w.label}_budget_exceeded` });
        res.status(503).json({
          code: "daily_budget_exceeded",
          message: "Service is temporarily unavailable. Please try again later.",
        });
        return;
      }
    }

    next();
  } catch (err) {
    req.log.error({ err }, "global_budget_check_failed");
    next(); // fail open
  }
}
