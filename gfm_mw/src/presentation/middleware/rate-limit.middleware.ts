import { Request, Response, NextFunction } from "express";
import { RateLimiterRedis, RateLimiterMemory, RateLimiterRes } from "rate-limiter-flexible";
import { redis } from "../../infrastructure/redis/redis-client";
import { env } from "../../config/env";
import { configService, ConfigKey } from "../../config/config-service";
import { logger } from "../../infrastructure/logger";
import { rateLimitExceededTotal } from "../../infrastructure/metrics";

// ── Limiter factory ────────────────────────────────────────────────────────────
// Redis primary + in-memory insurance. When Redis is down, the insurance limiter
// takes over automatically — per-process accuracy only, but acceptable (§4.2).

type LimiterRegistration = {
  limiter:   RateLimiterRedis;
  insurance: RateLimiterMemory;
  configKey: ConfigKey;
};

const LIMITER_REGISTRY: LimiterRegistration[] = [];

function makeLimiter(keyPrefix: string, configKey: ConfigKey, duration: number): RateLimiterRedis {
  const initialPoints = configService.get<number>(configKey, env[configKey] as number);
  const insurance = new RateLimiterMemory({ keyPrefix, points: initialPoints, duration });
  const limiter = new RateLimiterRedis({
    storeClient: redis,
    keyPrefix,
    points:   initialPoints,
    duration,
    insuranceLimiter: insurance,
  });
  LIMITER_REGISTRY.push({ limiter, insurance, configKey });
  return limiter;
}

// ── Limiter instances ──────────────────────────────────────────────────────────

const globalAiLimiter      = makeLimiter("rl:ai:global", "RL_AI_GLOBAL_HOURLY",  3_600);
const ipAiLimiter          = makeLimiter("rl:ai:ip",     "RL_AI_IP_HOURLY",      3_600);
const userAiHourlyLimiter  = makeLimiter("rl:ai:u:h",    "RL_AI_USER_HOURLY",    3_600);
const userAiDailyLimiter   = makeLimiter("rl:ai:u:d",    "RL_AI_USER_DAILY",    86_400);
const statusUserLimiter    = makeLimiter("rl:status:u",  "RL_STATUS_USER_MIN",       60);
const syncUserLimiter      = makeLimiter("rl:sync:u",    "RL_SYNC_USER_MIN",         60);
const rcIpLimiter          = makeLimiter("rl:rc:ip",     "RL_RC_IP_MIN",             60);
const defaultIpLimiter     = makeLimiter("rl:def:ip",    "RL_DEFAULT_IP_MIN",        60);

// Patch limiter capacity in-place whenever the runtime config reloads.
configService.onRefresh(() => {
  for (const { limiter, insurance, configKey } of LIMITER_REGISTRY) {
    const newPoints = configService.get<number>(configKey, limiter.points);
    if (newPoints === limiter.points) continue;
    limiter.points = newPoints;
    insurance.points = newPoints;
    logger.info({ configKey, points: newPoints }, "rate_limiter_points_updated");
  }
});

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
  code: "service_busy" | "rate_limited",
  status: 503 | 429,
  scope: string,
): (req: Request, res: Response, next: NextFunction) => Promise<void> {
  return async (req, res, next) => {
    const key = req.ip ?? "unknown";
    try {
      const rlRes = await limiter.consume(key);
      setRlHeaders(res, limiter.points, rlRes);
      next();
    } catch (err) {
      if (err instanceof RateLimiterRes) {
        setRlExceededHeaders(res, limiter.points, err);
        const retryAfter = Math.ceil(err.msBeforeNext / 1_000);
        req.log?.warn({ scope, retryAfter }, "rate_limit_exceeded");
        const routeKey = req.route
          ? `${req.method} ${req.route.path as string}`
          : `${req.method} ${req.path}`;
        rateLimitExceededTotal.inc({ scope, route: routeKey });
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
  scope: string,
): (req: Request, res: Response, next: NextFunction) => Promise<void> {
  return async (req, res, next) => {
    const key = String(req.user!.id);
    try {
      const rlRes = await limiter.consume(key);
      setRlHeaders(res, limiter.points, rlRes);
      next();
    } catch (err) {
      if (err instanceof RateLimiterRes) {
        setRlExceededHeaders(res, limiter.points, err);
        const retryAfter = Math.ceil(err.msBeforeNext / 1_000);
        req.log?.warn({ scope, userId: req.user!.id, retryAfter }, "rate_limit_exceeded");
        const routeKey = req.route
          ? `${req.method} ${req.route.path as string}`
          : `${req.method} ${req.path}`;
        rateLimitExceededTotal.inc({ scope, route: routeKey });
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
  globalAiLimiter, "service_busy", 503, "global",
);
export const aiIpLimitMiddleware = makeIpMiddleware(
  ipAiLimiter, "rate_limited", 429, "per-ip",
);

// For POST /ai/generate — used inside route handler after auth (Task 14)
export const aiUserHourlyLimitMiddleware = makeUserMiddleware(
  userAiHourlyLimiter, "per-user-hourly",
);
export const aiUserDailyLimitMiddleware = makeUserMiddleware(
  userAiDailyLimiter, "per-user-daily",
);

// For GET /user/status — used inside route handler after auth
export const statusUserLimitMiddleware = makeUserMiddleware(
  statusUserLimiter, "per-user-min",
);

// For POST /user/purchase/sync — 5 calls per minute per user
export const syncUserLimitMiddleware = makeUserMiddleware(
  syncUserLimiter, "per-user-sync",
);

// For POST /webhooks/revenuecat — mount before HMAC verification
export const rcIpLimitMiddleware = makeIpMiddleware(
  rcIpLimiter, "rate_limited", 429, "per-ip",
);

// Catch-all — mounted last in app.ts
export const defaultIpLimitMiddleware = makeIpMiddleware(
  defaultIpLimiter, "rate_limited", 429, "per-ip",
);
