import { Router } from "express";
import { z } from "zod";

import { authMiddleware } from "../middleware/auth.middleware";
import { premiumOnlyMiddleware } from "../middleware/premium.middleware";
import { pool } from "../../infrastructure/db/postgres";
import { PgFormWatchRepository } from "../../infrastructure/db/repositories/pg-form-watch.repository";

export const watchesRouter = Router();

const RegisterBody = z.object({
  formId:    z.string().min(1),
  watchId:   z.string().min(1),
  formTitle: z.string().default(""),
  expiresAt: z.string().datetime(),  // ISO-8601, e.g. "2026-05-27T22:00:00Z"
}).strict();

// POST /watches — store the (form_id, user_id) → watch_id mapping the app just
// created on Google's side. The app handles the actual forms.watches.create call
// because the OAuth token lives on-device.
watchesRouter.post("/", authMiddleware, premiumOnlyMiddleware, async (req, res, next) => {
  try {
    const parsed = RegisterBody.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ code: "invalid_body", message: parsed.error.message });
      return;
    }
    const repo = new PgFormWatchRepository(pool);
    await repo.upsert({
      watchId:   parsed.data.watchId,
      formId:    parsed.data.formId,
      userId:    req.user!.id,
      formTitle: parsed.data.formTitle,
      expiresAt: new Date(parsed.data.expiresAt),
    });
    res.status(204).end();
  } catch (err) {
    next(err);
  }
});

// DELETE /watches/:watchId — remove the mapping after the app calls forms.watches.delete.
watchesRouter.delete("/:watchId", authMiddleware, async (req, res, next) => {
  try {
    const repo = new PgFormWatchRepository(pool);
    await repo.deleteByWatchId(req.params.watchId);
    res.status(204).end();
  } catch (err) {
    next(err);
  }
});
