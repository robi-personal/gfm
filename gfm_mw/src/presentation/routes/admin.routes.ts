import { Router } from "express";
import { adminAuthMiddleware } from "../middleware/admin-auth.middleware";
import { configService, CONFIG_KEYS, ConfigKey } from "../../config/config-service";
import { PgConfigRepository } from "../../infrastructure/db/repositories/pg-config.repository";
import { PgQuotaProductRepository } from "../../infrastructure/db/repositories/pg-quota-product.repository";
import { PgQuotaWhitelistRepository } from "../../infrastructure/db/repositories/pg-quota-whitelist.repository";
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

// ── Quota products ────────────────────────────────────────────────────────────

// GET /admin/quota-products
adminRouter.get("/quota-products", async (_req, res) => {
  const repo = new PgQuotaProductRepository(pool);
  const products = await repo.getAll();
  res.json({ products });
});

// PATCH /admin/quota-products/:productId
adminRouter.patch("/quota-products/:productId", async (req, res) => {
  const { productId } = req.params;
  const { quotaAmount } = req.body as { quotaAmount?: unknown };

  if (typeof quotaAmount !== "number" || !Number.isInteger(quotaAmount) || quotaAmount < 0) {
    res.status(400).json({ code: "bad_request", message: "quotaAmount must be a non-negative integer." });
    return;
  }

  const repo = new PgQuotaProductRepository(pool);
  const existing = await repo.getById(productId);
  if (!existing) {
    res.status(404).json({ code: "not_found", message: `Product '${productId}' not found.` });
    return;
  }

  await repo.setAmount(productId, quotaAmount);
  const updated = await repo.getById(productId);
  res.json({ product: updated });
});

// ── Quota whitelist ───────────────────────────────────────────────────────────

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// GET /admin/whitelist
adminRouter.get("/whitelist", async (_req, res) => {
  const repo = new PgQuotaWhitelistRepository(pool);
  const entries = await repo.getAll();
  res.json({ entries });
});

// POST /admin/whitelist
adminRouter.post("/whitelist", async (req, res) => {
  const { email, note } = req.body as { email?: unknown; note?: unknown };

  if (typeof email !== "string" || !EMAIL_RE.test(email)) {
    res.status(400).json({ code: "bad_request", message: "A valid email is required." });
    return;
  }
  if (note !== undefined && (typeof note !== "string" || note.length > 500)) {
    res.status(400).json({ code: "bad_request", message: "note must be a string of max 500 characters." });
    return;
  }

  const repo  = new PgQuotaWhitelistRepository(pool);
  const entry = await repo.add(email, note ?? null, env.ADMIN_EMAIL);
  res.json({ entry });
});

// DELETE /admin/whitelist/:email
adminRouter.delete("/whitelist/:email", async (req, res) => {
  const { email } = req.params;
  const repo = new PgQuotaWhitelistRepository(pool);

  const all = await repo.getAll();
  const exists = all.some((e) => e.email === email.toLowerCase());
  if (!exists) {
    res.status(404).json({ code: "not_found", message: `Email '${email}' not found in whitelist.` });
    return;
  }

  await repo.remove(email);
  res.status(204).end();
});

