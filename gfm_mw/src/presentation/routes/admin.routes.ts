import { Router } from "express";
import { adminAuthMiddleware } from "../middleware/admin-auth.middleware";
import { configService, CONFIG_KEYS, ConfigKey } from "../../config/config-service";
import { PgConfigRepository } from "../../infrastructure/db/repositories/pg-config.repository";
import { PgAiGenerationRepository } from "../../infrastructure/db/repositories/pg-ai-generation.repository";
import { pool } from "../../infrastructure/db/postgres";
import { logger } from "../../infrastructure/logger";
import { env } from "../../config/env";

export const adminRouter = Router();

// POST /admin/login — verify email + password, return bearer token on success
adminRouter.post("/login", (req, res) => {
  const { email, password } = req.body as { email?: string; password?: string };
  if (!email || !password) {
    res.status(400).json({ code: "bad_request", message: "email and password are required." });
    return;
  }
  if (email !== env.ADMIN_EMAIL || password !== env.ADMIN_PASSWORD) {
    res.status(401).json({ code: "unauthorized", message: "Invalid credentials." });
    return;
  }
  res.json({ token: env.ADMIN_TOKEN });
});

// All routes below require a valid bearer token
adminRouter.use(adminAuthMiddleware);

function currentConfig(): Record<string, number | boolean> {
  const out: Record<string, number | boolean> = {};
  for (const key of CONFIG_KEYS) {
    out[key] = configService.get<number | boolean>(key, false);
  }
  return out;
}

// GET /admin/config — full config snapshot (env defaults merged with DB overrides)
adminRouter.get("/config", (_req, res) => {
  res.json({ config: currentConfig() });
});

// PATCH /admin/config — write keys to DB then reload; returns updated snapshot
adminRouter.patch("/config", async (req, res) => {
  const body = req.body as Record<string, unknown>;
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    res.status(400).json({ code: "bad_request", message: "Body must be a JSON object." });
    return;
  }

  const updates: Record<string, string> = {};
  for (const [key, value] of Object.entries(body)) {
    if (!CONFIG_KEYS.includes(key as ConfigKey)) {
      res.status(400).json({ code: "bad_request", message: `Unknown config key: ${key}` });
      return;
    }
    if (typeof value !== "string" && typeof value !== "number" && typeof value !== "boolean") {
      res.status(400).json({ code: "bad_request", message: `Invalid value for key: ${key}` });
      return;
    }
    updates[key] = String(value);
  }

  if (Object.keys(updates).length === 0) {
    res.status(400).json({ code: "bad_request", message: "No keys provided." });
    return;
  }

  try {
    const repo = new PgConfigRepository(pool);
    await Promise.all(Object.entries(updates).map(([k, v]) => repo.set(k, v)));
    await configService.reload();
    logger.info({ keys: Object.keys(updates) }, "admin_config_updated");
    res.json({ config: currentConfig() });
  } catch (err) {
    logger.error({ err }, "admin_config_update_failed");
    res.status(500).json({ code: "internal_error", message: "Failed to update config." });
  }
});

// GET /admin/spend — current global spend for each rolling window
adminRouter.get("/spend", async (_req, res) => {
  const now = Date.now();
  const MS = 24 * 60 * 60 * 1_000;
  const repo = new PgAiGenerationRepository(pool);
  try {
    const [daily, weekly, monthly] = await Promise.all([
      repo.getGlobalSpendUsd(now - MS),
      repo.getGlobalSpendUsd(now - 7 * MS),
      repo.getGlobalSpendUsd(now - 30 * MS),
    ]);
    res.json({ spend: { daily, weekly, monthly } });
  } catch (err) {
    logger.error({ err }, "admin_spend_query_failed");
    res.status(500).json({ code: "internal_error", message: "Failed to query spend." });
  }
});
