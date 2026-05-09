import { Router } from "express";
import { authMiddleware } from "../middleware/auth.middleware";
import { denylistMiddleware } from "../middleware/kill-switch.middleware";
import { statusUserLimitMiddleware } from "../middleware/rate-limit.middleware";
import { PgUserRepository } from "../../infrastructure/db/repositories/pg-user.repository";
import { pool } from "../../infrastructure/db/postgres";
import { env } from "../../config/env";
import { configService } from "../../config/config-service";

// Quota constants — source of truth is api-contract.md §4.1 / §4.3
const FREE_LIMIT    = 3;
const PREMIUM_LIMIT = 50;

export const userRouter = Router();

// GET /user/status
// Auth → denylist → rate limit → auto-reset expired quota → return snapshot
userRouter.get(
  "/status",
  authMiddleware,
  denylistMiddleware,
  statusUserLimitMiddleware,
  async (req, res, next) => {
    try {
      const userRepo = new PgUserRepository(pool);

      await userRepo.resetFreeQuotaIfExpired(req.user!.id);
      await userRepo.resetYoutubeMinutesIfNeeded(req.user!.id);

      const user = await userRepo.findById(req.user!.id);
      if (!user) {
        res.status(401).json({ code: "invalid_token", message: "User not found." });
        return;
      }

      const ytLimit = configService.get<number>("YOUTUBE_MONTHLY_MINUTES", env.YOUTUBE_MONTHLY_MINUTES);
      res.json({
        isPremium:               env.RC_BYPASS_PREMIUM || user.isPremium,
        aiFreeUsed:              user.aiFreeUsed,
        aiFreeLimit:             FREE_LIMIT,
        freeResetsAt:            user.freeMonthResetAt?.toISOString() ?? null,
        aiPremiumUsed:           user.aiPremiumUsed,
        aiPremiumLimit:          PREMIUM_LIMIT,
        premiumResetsAt:         user.premiumResetAt?.toISOString() ?? null,
        gracePeriodUntil:        user.gracePeriodUntil?.toISOString() ?? null,
        youtubeMinutesUsed:      user.youtubeMinutesUsed,
        youtubeMinutesLimit:     ytLimit,
        youtubeMinutesResetsAt:  user.youtubeMinutesResetAt?.toISOString() ?? null,
      });
    } catch (err) {
      next(err);
    }
  },
);
