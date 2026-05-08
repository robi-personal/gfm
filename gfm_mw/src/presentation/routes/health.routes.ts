import crypto from "node:crypto";
import { Router, Request, Response } from "express";
import { env } from "../../config/env";
import { pool } from "../../infrastructure/db/postgres";
import { redis } from "../../infrastructure/redis/redis-client";
import { PgAiGenerationRepository } from "../../infrastructure/db/repositories/pg-ai-generation.repository";
import {
  register,
  healthDegraded,
  geminiSpendUsdToday,
} from "../../infrastructure/metrics";
import { getLastGeminiHealth } from "../../infrastructure/gemini/gemini-client";

export const healthRouter = Router();

// Constant-time Bearer token check. Returns false and sends 401 if invalid.
function checkBearerToken(req: Request, res: Response): boolean {
  const header = req.headers.authorization ?? "";
  const token  = header.startsWith("Bearer ") ? header.slice(7) : "";
  const expected = Buffer.from(env.HEALTH_TOKEN, "utf8");
  const provided  = Buffer.from(token,           "utf8");
  const valid =
    expected.length > 0 &&
    expected.length === provided.length &&
    crypto.timingSafeEqual(expected, provided);
  if (!valid) {
    res.status(401).json({ code: "invalid_token", message: "Missing or invalid token." });
  }
  return valid;
}

async function checkPostgres(): Promise<{ ok: boolean; latencyMs: number }> {
  const start = Date.now();
  try {
    await pool.query("SELECT 1");
    return { ok: true, latencyMs: Date.now() - start };
  } catch {
    return { ok: false, latencyMs: Date.now() - start };
  }
}

async function checkRedis(): Promise<{ ok: boolean; latencyMs: number }> {
  const start = Date.now();
  try {
    await redis.ping();
    return { ok: true, latencyMs: Date.now() - start };
  } catch {
    return { ok: false, latencyMs: Date.now() - start };
  }
}

// ── GET /health ───────────────────────────────────────────────────────────────
// Reports system health: Postgres, Redis, Gemini, kill switches, daily spend.
// Auth: Bearer <HEALTH_TOKEN>. See rate-limiting-abuse.md §10.4.

healthRouter.get("/health", async (req: Request, res: Response): Promise<void> => {
  if (!checkBearerToken(req, res)) return;

  const [pg, rd] = await Promise.all([checkPostgres(), checkRedis()]);
  const geminiHealth = getLastGeminiHealth();

  // Update Prometheus gauges so alerting rules fire on the same data.
  healthDegraded.set({ dep: "postgres" }, pg.ok ? 0 : 1);
  healthDegraded.set({ dep: "redis" },    rd.ok ? 0 : 1);
  healthDegraded.set({ dep: "gemini" },   geminiHealth.ok ? 0 : 1);

  let todayUsd: number | null = null;
  try {
    const repo = new PgAiGenerationRepository(pool);
    todayUsd = await repo.getGlobalDailySpendUsd();
    geminiSpendUsdToday.set(todayUsd);
  } catch {
    // DB unavailable for spend computation — already reported via pg.ok
  }

  const cap = env.MAX_DAILY_GEMINI_SPEND_USD;

  // Window resets at next UTC midnight.
  const now = new Date();
  const windowResetsAt = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1),
  ).toISOString();

  // "down" if Postgres is gone (can't serve); "degraded" for Redis or Gemini.
  let status: "ok" | "degraded" | "down" = "ok";
  if (!pg.ok) {
    status = "down";
  } else if (!rd.ok || !geminiHealth.ok) {
    status = "degraded";
  }

  res.json({
    status,
    uptimeSeconds: Math.floor(process.uptime()),
    version: process.env["npm_package_version"] ?? "unknown",
    killSwitches: {
      aiGenerationDisabled:   env.AI_GENERATION_DISABLED,
      userDenylistCount:      env.USER_DENYLIST.size,
      maxDailyGeminiSpendUsd: cap,
    },
    spend: {
      todayUsd,
      capUsd: cap,
      windowResetsAt,
    },
    deps: {
      postgres: { ok: pg.ok,          latencyMs: pg.latencyMs },
      redis:    { ok: rd.ok,          latencyMs: rd.latencyMs },
      gemini:   { ok: geminiHealth.ok, checkedAt: geminiHealth.checkedAt },
    },
  });
});

// ── GET /metrics ──────────────────────────────────────────────────────────────
// Prometheus scrape endpoint. Same HEALTH_TOKEN auth as /health.

healthRouter.get("/metrics", async (req: Request, res: Response): Promise<void> => {
  if (!checkBearerToken(req, res)) return;
  res.set("Content-Type", register.contentType);
  res.end(await register.metrics());
});
