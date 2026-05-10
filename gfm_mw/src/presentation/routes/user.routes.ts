import { Router } from "express";
import { authMiddleware } from "../middleware/auth.middleware";
import { denylistMiddleware } from "../middleware/kill-switch.middleware";
import { statusUserLimitMiddleware } from "../middleware/rate-limit.middleware";
import { PgUserRepository } from "../../infrastructure/db/repositories/pg-user.repository";
import { PgQuotaWhitelistRepository } from "../../infrastructure/db/repositories/pg-quota-whitelist.repository";
import { pool } from "../../infrastructure/db/postgres";
import { env } from "../../config/env";
import { configService } from "../../config/config-service";

export const userRouter = Router();

// GET /user/status
userRouter.get(
  "/status",
  authMiddleware,
  denylistMiddleware,
  statusUserLimitMiddleware,
  async (req, res, next) => {
    try {
      const userRepo      = new PgUserRepository(pool);
      const whitelistRepo = new PgQuotaWhitelistRepository(pool);

      await userRepo.resetYoutubeMinutesIfNeeded(req.user!.id);

      const [user, unlimited] = await Promise.all([
        userRepo.findById(req.user!.id),
        whitelistRepo.contains(req.user!.email),
      ]);

      if (!user) {
        res.status(401).json({ code: "invalid_token", message: "User not found." });
        return;
      }

      const ytLimit = configService.get<number>("YOUTUBE_MONTHLY_MINUTES", env.YOUTUBE_MONTHLY_MINUTES);
      res.json({
        isPremium:               env.RC_BYPASS_PREMIUM || user.isPremium,
        quotaBalance:            user.quotaBalance,
        unlimited,
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
