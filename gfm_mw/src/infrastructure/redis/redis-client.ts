import Redis from "ioredis";
import { env } from "../../config/env";
import { logger } from "../logger";

export const redis = new Redis(env.REDIS_URL, {
  enableReadyCheck: false,   // don't block — insurance limiter handles Redis-down
  maxRetriesPerRequest: 1,
  retryStrategy: (times) => (times > 3 ? null : Math.min(times * 200, 1_000)),
});

redis.on("error", (err) => {
  logger.warn({ err }, "redis_error");
});

redis.on("connect", () => {
  logger.info("redis_connected");
});
