import { Request, Response, NextFunction } from "express";
import { env } from "../../config/env";
import { pool } from "../../infrastructure/db/postgres";
import { PgAiGenerationRepository } from "../../infrastructure/db/repositories/pg-ai-generation.repository";
import {
  killSwitchTrippedTotal,
  costBreakerTrippedTotal,
  geminiSpendUsdToday,
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

// ── 3. Per-user 24h cost circuit breaker ──────────────────────────────────────
// Runs after auth on /ai/generate. One DB query per request (index: user_id + created_at).
// Includes both successful and failed rows per rate-limiting-abuse.md §8.1.
export async function perUserBudgetMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const cap = env.MAX_USER_DAILY_GEMINI_USD;
  if (cap === 0) {
    next();
    return;
  }

  try {
    const since24hMs = Date.now() - 24 * 60 * 60 * 1_000;
    const repo = new PgAiGenerationRepository(pool);
    const spend = await repo.getTotalSpendUsd(req.user!.id, since24hMs);

    if (spend >= cap) {
      req.log.warn(
        { userId: req.user!.id, spendUsd: spend, capUsd: cap },
        "cost_breaker_tripped_per_user",
      );
      costBreakerTrippedTotal.inc({ scope: "per-user" });
      res.status(503).json({
        code: "daily_budget_exceeded",
        message: "You have reached the daily usage limit. Please try again tomorrow.",
      });
      return;
    }

    next();
  } catch (err) {
    req.log.error({ err }, "per_user_budget_check_failed");
    next(); // fail open — don't block everyone when DB is slow
  }
}

// ── 4. MAX_DAILY_GEMINI_SPEND_USD ─────────────────────────────────────────────
// Runs after auth. 60s in-memory cached DB query. See rate-limiting-abuse.md §8.2.
let globalSpendCache = { value: 0, fetchedAt: 0 };

export async function dailyBudgetMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  if (env.MAX_DAILY_GEMINI_SPEND_USD === 0) {
    // Cap of 0 means disabled — never block.
    next();
    return;
  }

  try {
    const now = Date.now();
    if (now - globalSpendCache.fetchedAt >= 60_000) {
      const repo = new PgAiGenerationRepository(pool);
      const spend = await repo.getGlobalDailySpendUsd();
      globalSpendCache = { value: spend, fetchedAt: now };
    }

    if (globalSpendCache.value >= env.MAX_DAILY_GEMINI_SPEND_USD) {
      req.log.warn(
        { spendUsd: globalSpendCache.value, capUsd: env.MAX_DAILY_GEMINI_SPEND_USD },
        "kill_switch_tripped_daily_budget_exceeded",
      );
      killSwitchTrippedTotal.inc({ which: "daily_budget_exceeded" });
      geminiSpendUsdToday.set(globalSpendCache.value);
      res.status(503).json({
        code: "daily_budget_exceeded",
        message: "Service is temporarily unavailable. Please try again tomorrow.",
      });
      return;
    }
    geminiSpendUsdToday.set(globalSpendCache.value);

    next();
  } catch (err) {
    // DB unavailable — fail open (let the request through rather than blocking everyone).
    req.log.error({ err }, "daily_budget_check_failed");
    next();
  }
}
