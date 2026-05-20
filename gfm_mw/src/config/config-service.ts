import { env } from "./env";
import { logger } from "../infrastructure/logger";
import { pool } from "../infrastructure/db/postgres";
import { PgConfigRepository } from "../infrastructure/db/repositories/pg-config.repository";
import { ConfigRepository } from "../domain/repositories/config.repository";

type ScalarType = "number" | "boolean" | "string";

// Keys that may be overridden at runtime via the server_config table.
// Names mirror env.ts field names so the admin API can write them through directly.
const KEY_TYPES = {
  // Rate limits
  RL_AI_GLOBAL_HOURLY:          "number",
  RL_AI_IP_HOURLY:              "number",
  RL_AI_USER_HOURLY:            "number",
  RL_AI_USER_DAILY:             "number",
  RL_STATUS_USER_MIN:           "number",
  RL_RC_IP_MIN:                 "number",
  RL_DEFAULT_IP_MIN:            "number",
  // Kill switch
  AI_GENERATION_DISABLED:       "boolean",
  // YouTube
  YOUTUBE_MONTHLY_MINUTES:      "number",
  // Document settings
  PDF_PAGES_PER_QUOTA:          "number",
  // Push notifications
  NOTIFICATION_BODY_TEMPLATE:   "string",
} as const satisfies Record<string, ScalarType>;

export type ConfigKey = keyof typeof KEY_TYPES;
export const CONFIG_KEYS = Object.keys(KEY_TYPES) as ConfigKey[];

function parseValue(raw: string, type: ScalarType): number | boolean | string | null {
  if (type === "number") {
    const n = Number(raw);
    return Number.isFinite(n) ? n : null;
  }
  if (type === "string") {
    return raw;
  }
  if (raw === "true") return true;
  if (raw === "false") return false;
  return null;
}

class ConfigService {
  private _config: Map<string, number | boolean | string> = new Map();
  private callbacks: Array<() => void> = [];
  private repo: ConfigRepository = new PgConfigRepository(pool);

  async load(): Promise<void> {
    // Seed from env defaults — env values are already typed and validated by zod.
    this._config.clear();
    for (const key of CONFIG_KEYS) {
      this._config.set(key, env[key] as number | boolean | string);
    }

    // Overlay DB overrides. If the DB is unreachable, fall back to env entirely.
    try {
      const overrides = await this.repo.getAll();
      for (const [key, raw] of Object.entries(overrides)) {
        const type = KEY_TYPES[key as ConfigKey];
        if (!type) {
          logger.warn({ key }, "config_unknown_key_in_db");
          continue;
        }
        const parsed = parseValue(raw, type);
        if (parsed === null) {
          logger.warn({ key, raw }, "config_invalid_value_in_db");
          continue;
        }
        this._config.set(key, parsed);
      }
    } catch (err) {
      logger.warn({ err }, "config_db_load_failed_using_env_only");
    }

    // Notify subscribers so derived state (e.g. rate limiter .points) syncs.
    this.fireCallbacks();
  }

  get<T>(key: string, fallback: T): T {
    return this._config.has(key) ? (this._config.get(key) as T) : fallback;
  }

  async reload(): Promise<void> {
    await this.load();
  }

  onRefresh(cb: () => void): void {
    this.callbacks.push(cb);
  }

  private fireCallbacks(): void {
    for (const cb of this.callbacks) {
      try {
        cb();
      } catch (err) {
        logger.warn({ err }, "config_refresh_callback_failed");
      }
    }
  }
}

export const configService = new ConfigService();
