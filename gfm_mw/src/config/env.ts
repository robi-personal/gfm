import "dotenv/config";
import { z } from "zod";

const schema = z.object({
  // Server
  NODE_ENV: z.enum(["development", "staging", "production"]).default("development"),
  PORT: z.coerce.number().default(3000),
  LOG_LEVEL: z.enum(["debug", "info", "warn", "error"]).default("info"),

  // Database
  DATABASE_URL: z.string().min(1),

  // Redis
  REDIS_URL: z.string().min(1).default("redis://localhost:6379"),

  // Google auth
  GOOGLE_CLIENT_ID: z.string().min(1),

  // Gemini
  GEMINI_API_KEY: z.string().min(1),

  // RevenueCat
  RC_WEBHOOK_SECRET: z.string().min(1),

  // Sentry (optional — skipped if absent)
  SENTRY_DSN: z.string().optional(),

  // Observability
  HEALTH_TOKEN: z.string().min(32),

  // Kill switches
  AI_GENERATION_DISABLED: z
    .string()
    .default("false")
    .transform((v) => v === "true"),
  MAX_DAILY_GEMINI_SPEND_USD: z.coerce.number().min(0).default(10),
  USER_DENYLIST: z
    .string()
    .default("")
    .transform((v) => new Set(v.split(",").map((s) => s.trim()).filter(Boolean))),

  // Rate limits
  RL_AI_GLOBAL_HOURLY: z.coerce.number().default(300),
  RL_AI_IP_HOURLY: z.coerce.number().default(30),
  RL_AI_USER_HOURLY: z.coerce.number().default(10),
  RL_AI_USER_DAILY: z.coerce.number().default(50),
  RL_STATUS_USER_MIN: z.coerce.number().default(60),
  RL_RC_IP_MIN: z.coerce.number().default(120),
  RL_DEFAULT_IP_MIN: z.coerce.number().default(120),

  // Cost circuit breaker
  MAX_USER_DAILY_GEMINI_USD: z.coerce.number().default(0.5),
});

const result = schema.safeParse(process.env);

if (!result.success) {
  console.error("❌ Invalid environment variables:");
  console.error(JSON.stringify(result.error.flatten().fieldErrors, null, 2));
  process.exit(1);
}

export const env = result.data;
export type Env = typeof env;
