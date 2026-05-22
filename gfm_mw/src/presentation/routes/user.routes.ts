import { Router } from "express";
import { authMiddleware } from "../middleware/auth.middleware";
import { denylistMiddleware } from "../middleware/kill-switch.middleware";
import { statusUserLimitMiddleware, syncUserLimitMiddleware } from "../middleware/rate-limit.middleware";
import { PgUserRepository } from "../../infrastructure/db/repositories/pg-user.repository";
import { PgQuotaWhitelistRepository } from "../../infrastructure/db/repositories/pg-quota-whitelist.repository";
import { PgQuotaProductRepository } from "../../infrastructure/db/repositories/pg-quota-product.repository";
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

      const [, unlimited] = await Promise.all([
        // Apply free monthly grant if due so new users see their balance immediately.
        (async () => {
          if (req.user!.tier !== "free") return;
          const productRepo = new PgQuotaProductRepository(pool);
          const freeProduct = await productRepo.getById("free");
          if (freeProduct) await userRepo.applyFreeGrantIfDue(req.user!.id, freeProduct);
        })(),
        whitelistRepo.contains(req.user!.email),
      ]);

      const user = await userRepo.findById(req.user!.id);

      if (!user) {
        res.status(401).json({ code: "invalid_token", message: "User not found." });
        return;
      }

      const ytLimit = configService.get<number>("YOUTUBE_MONTHLY_MINUTES", env.YOUTUBE_MONTHLY_MINUTES);
      // Mirror auth.middleware tier logic: whitelist is a full premium override.
      res.json({
        isPremium:               req.user!.tier === "premium",
        quotaBalance:            user.quotaBalance,
        unlimited,
        gracePeriodUntil:        user.gracePeriodUntil?.toISOString() ?? null,
        subscriptionProductId:   user.subscriptionProductId ?? null,
        youtubeMinutesUsed:      user.youtubeMinutesUsed,
        youtubeMinutesLimit:     ytLimit,
        youtubeMinutesResetsAt:  user.youtubeMinutesResetAt?.toISOString() ?? null,
      });
    } catch (err) {
      next(err);
    }
  },
);

// POST /user/purchase/sync
// Called by the app right after a RevenueCat purchase to ensure premium is
// reflected even if the webhook was delayed or missed.
userRouter.post(
  "/purchase/sync",
  authMiddleware,
  denylistMiddleware,
  syncUserLimitMiddleware,
  async (req, res, next) => {
    try {
      if (!env.RC_SECRET_API_KEY) {
        res.status(503).json({ code: "unavailable", message: "Purchase sync is not configured." });
        return;
      }

      const rcRes = await fetch(
        `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(req.user!.googleSub)}`,
        { headers: { Authorization: `Bearer ${env.RC_SECRET_API_KEY}`, "Content-Type": "application/json" } },
      );

      if (!rcRes.ok) {
        req.log.warn({ status: rcRes.status, user_id: req.user!.id }, "rc_sync_fetch_failed");
        res.status(502).json({ code: "rc_error", message: "Could not reach RevenueCat." });
        return;
      }

      const body = await rcRes.json() as {
        subscriber: {
          entitlements: Record<string, { expires_date: string | null; product_identifier: string }>;
        };
      };

      const entitlement = body.subscriber.entitlements["GFMPremium"];
      const isActive = entitlement != null &&
        (entitlement.expires_date == null || new Date(entitlement.expires_date) > new Date());

      if (!isActive) {
        req.log.info({ user_id: req.user!.id }, "rc_sync_no_active_entitlement");
        res.json({ synced: false });
        return;
      }

      const productId = entitlement.product_identifier;
      const userRepo    = new PgUserRepository(pool);
      const productRepo = new PgQuotaProductRepository(pool);
      const user        = await userRepo.findById(req.user!.id);

      if (!user) {
        res.status(401).json({ code: "invalid_token", message: "User not found." });
        return;
      }

      const product = await productRepo.getById(productId);
      if (!product) {
        req.log.warn({ user_id: user.id, product_id: productId }, "rc_sync_unknown_product");
        res.json({ synced: false });
        return;
      }
      const claimed = await userRepo.claimPremiumAndCredit(
        user.id, product.quotaAmount, product.productId, "subscription", `sync:${req.user!.googleSub}`,
      );
      req.log.info(
        { user_id: user.id, product_id: productId, claimed },
        claimed ? "rc_sync_premium_granted" : "rc_sync_already_premium",
      );

      res.json({ synced: true });
    } catch (err) {
      next(err);
    }
  },
);
