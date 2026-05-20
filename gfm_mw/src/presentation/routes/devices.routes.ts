import { Router } from "express";
import { z } from "zod";

import { authMiddleware } from "../middleware/auth.middleware";
import { pool } from "../../infrastructure/db/postgres";
import { PgDeviceTokenRepository } from "../../infrastructure/db/repositories/pg-device-token.repository";

export const devicesRouter = Router();

const RegisterBody = z.object({
  fcmToken: z.string().min(1),
  platform: z.enum(["ios", "android"]),
}).strict();

// POST /devices — upsert the current device's FCM token for the authenticated user.
devicesRouter.post("/", authMiddleware, async (req, res, next) => {
  try {
    const parsed = RegisterBody.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ code: "invalid_body", message: parsed.error.message });
      return;
    }
    const repo = new PgDeviceTokenRepository(pool);
    await repo.upsert(req.user!.id, parsed.data.fcmToken, parsed.data.platform);
    res.status(204).end();
  } catch (err) {
    next(err);
  }
});

// DELETE /devices/:token — unregister a specific device token (called on sign-out).
devicesRouter.delete("/:token", authMiddleware, async (req, res, next) => {
  try {
    const repo = new PgDeviceTokenRepository(pool);
    await repo.deleteByToken(req.params.token);
    res.status(204).end();
  } catch (err) {
    next(err);
  }
});
