import { Request, Response, NextFunction } from "express";
import { RateLimiterRedis, RateLimiterMemory, RateLimiterRes } from "rate-limiter-flexible";
import { redis } from "../../infrastructure/redis/redis-client";
import { env } from "../../config/env";
import { logger } from "../../infrastructure/logger";

// ── Limiter factory ────────────────────────────────────────────────────────────
// Redis primary + in-memory insurance. When Redis is down, the insurance limiter
// takes over automatically — per-process accuracy only, but acceptable (§4.2).

function makeLimiter(keyPrefix: string, points: number, duration: number): RateLimiterRedis {
  return new RateLimiterRedis({
    storeClient: redis,
    keyPrefix,
    points,
    duration,
    insuranceLimiter: new RateLimiterMemory({ keyPrefix, points, duration }),
  });
}

// ── Limiter instances ──────────────────────────────────────────────────────────

const globalAiLimiter      = makeLimiter("rl:ai:global", env.RL_AI_GLOBAL_HOURLY,  3_600);
const ipAiLimiter          = makeLimiter("rl:ai:ip",     env.RL_AI_IP_HOURLY,      3_600);
const userAiHourlyLimiter  = makeLimiter("rl:ai:u:h",   env.RL_AI_USER_HOURLY,    3_600);
const userAiDailyLimiter   = makeLimiter("rl:ai:u:d",   env.RL_AI_USER_DAILY,    86_400);
const statusUserLimiter    = makeLimiter("rl:status:u",  env.RL_STATUS_USER_MIN,      60);
const rcIpLimiter          = makeLimiter("rl:rc:ip",     env.RL_RC_IP_MIN,            60);
const defaultIpLimiter     = makeLimiter("rl:def:ip",    env.RL_DEFAULT_IP_MIN,       60);

// ── Header helpers ─────────────────────────────────────────────────────────────

function setRlHeaders(res: Response, limit: number, rlRes: RateLimiterRes): void {
  res.set("X-RateLimit-Limit",     String(limit));
  res.set("X-RateLimit-Remaining", String(Math.max(0, rlRes.remainingPoints)));
  res.set("X-RateLimit-Reset",     String(Math.floor((Date.now() + rlRes.msBeforeNext) / 1_000)));
}

function setRlExceededHeaders(res: Response, limit: number, rlRes: RateLimiterRes): void {
  const retryAfter = Math.ceil(rlRes.msBeforeNext / 1_000);
  res.set("X-RateLimit-Limit",     String(limit));
  res.set("X-RateLimit-Remaining", "0");
  res.set("X-RateLimit-Reset",     String(Math.floor((Date.now() + rlRes.msBeforeNext) / 1_000)));
  res.set("Retry-After",           String(retryAfter));
}

// ── Middleware factories ───────────────────────────────────────────────────────

type RlResult = RateLimiterRedis;

function makeIpMiddleware(
  limiter: RlResult,
  limit: number,
  code: "service_busy" | "rate_limited",
  status: 503 | 429,
  scope: string,
): (req: Request, res: Response, next: NextFunction) => Promise<void> {
  return async (req, res, next) => {
    const key = req.ip ?? "unknown";
    try {
      const rlRes = await limiter.consume(key);
      setRlHeaders(res, limit, rlRes);
      next();
    } catch (err) {
      if (err instanceof RateLimiterRes) {
        setRlExceededHeaders(res, limit, err);
        const retryAfter = Math.ceil(err.msBeforeNext / 1_000);
        req.log?.warn({ scope, retryAfter }, "rate_limit_exceeded");
        res.status(status).json({
          code,
          message: status === 503
            ? "Service is unusually busy. Please try again shortly."
            : "Too many requests. Please slow down.",
          details: { retryAfter, scope },
        });
      } else {
        logger.warn({ err, scope }, "rate_limiter_unexpected_error");
        next(); // fail open on unexpected errors
      }
    }
  };
}

function makeUserMiddleware(
  limiter: RlResult,
  limit: number,
  scope: string,
): (req: Request, res: Response, next: NextFunction) => Promise<void> {
  return async (req, res, next) => {
    const key = String(req.user!.id);
    try {
      const rlRes = await limiter.consume(key);
      setRlHeaders(res, limit, rlRes);
      next();
    } catch (err) {
      if (err instanceof RateLimiterRes) {
        setRlExceededHeaders(res, limit, err);
        const retryAfter = Math.ceil(err.msBeforeNext / 1_000);
        req.log?.warn({ scope, userId: req.user!.id, retryAfter }, "rate_limit_exceeded");
        res.status(429).json({
          code: "rate_limited",
          message: "Too many requests. Please slow down.",
          details: { retryAfter, scope },
        });
      } else {
        logger.warn({ err, scope }, "rate_limiter_unexpected_error");
        next(); // fail open
      }
    }
  };
}

// ── Exported middleware ────────────────────────────────────────────────────────

// For /ai/* — mount before auth (§12 steps 5–6)
export const aiGlobalLimitMiddleware = makeIpMiddleware(
  globalAiLimiter, env.RL_AI_GLOBAL_HOURLY, "service_busy", 503, "global",
);
export const aiIpLimitMiddleware = makeIpMiddleware(
  ipAiLimiter, env.RL_AI_IP_HOURLY, "rate_limited", 429, "per-ip",
);

// For POST /ai/generate — used inside route handler after auth (Task 14)
export const aiUserHourlyLimitMiddleware = makeUserMiddleware(
  userAiHourlyLimiter, env.RL_AI_USER_HOURLY, "per-user-hourly",
);
export const aiUserDailyLimitMiddleware = makeUserMiddleware(
  userAiDailyLimiter, env.RL_AI_USER_DAILY, "per-user-daily",
);

// For GET /user/status — used inside route handler after auth
export const statusUserLimitMiddleware = makeUserMiddleware(
  statusUserLimiter, env.RL_STATUS_USER_MIN, "per-user-min",
);

// For POST /webhooks/revenuecat — mount before HMAC verification
export const rcIpLimitMiddleware = makeIpMiddleware(
  rcIpLimiter, env.RL_RC_IP_MIN, "rate_limited", 429, "per-ip",
);

// Catch-all — mounted last in app.ts
export const defaultIpLimitMiddleware = makeIpMiddleware(
  defaultIpLimiter, env.RL_DEFAULT_IP_MIN, "rate_limited", 429, "per-ip",
);
