import { Router } from "express";
import { authMiddleware } from "../middleware/auth.middleware";
import { denylistMiddleware } from "../middleware/kill-switch.middleware";
import { PgUserRepository } from "../../infrastructure/db/repositories/pg-user.repository";
import { PgQuotaWhitelistRepository } from "../../infrastructure/db/repositories/pg-quota-whitelist.repository";
import { PgQuotaProductRepository } from "../../infrastructure/db/repositories/pg-quota-product.repository";
import { PgAppleSubscriptionBindingRepository } from "../../infrastructure/db/repositories/pg-apple-subscription-binding.repository";
import { pool } from "../../infrastructure/db/postgres";
import { env } from "../../config/env";
import { configService } from "../../config/config-service";

export const userRouter = Router();

// GET /user/status
userRouter.get(
  "/status",
  authMiddleware,
  denylistMiddleware,
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

// DELETE /user/account
userRouter.delete(
  "/account",
  authMiddleware,
  async (req, res, next) => {
    try {
      const userRepo = new PgUserRepository(pool);
      await userRepo.requestDeletion(req.user!.id);
      res.status(204).send();
    } catch (err) {
      next(err);
    }
  },
);

// POST /user/apple/check
// Pre-purchase check. The app fetches the Apple originalTransactionId from
// StoreKit (via native channel) and sends it here. If that transaction is
// already bound to a different Google account, returns allowed:false with a
// user-facing message; the app shows a dialog and does not start the purchase.
userRouter.post(
  "/apple/check",
  authMiddleware,
  async (req, res, next) => {
    try {
      const { original_transaction_id } = req.body as { original_transaction_id?: string };
      if (!original_transaction_id || typeof original_transaction_id !== "string") {
        res.status(400).json({ code: "invalid_input", message: "original_transaction_id is required." });
        return;
      }

      const bindingRepo = new PgAppleSubscriptionBindingRepository(pool);
      const boundUserId = await bindingRepo.findByTransactionId(original_transaction_id);

      if (boundUserId !== null && boundUserId !== req.user!.id) {
        req.log.warn(
          { user_id: req.user!.id, bound_user_id: boundUserId, original_transaction_id },
          "apple_check_binding_conflict",
        );
        res.json({
          allowed: false,
          message: "This Apple ID already has a subscription linked to another account. Please use a different Apple ID or go to Settings and change your Apple ID.",
        });
        return;
      }

      res.json({ allowed: true });
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

      // Always ensure premium status and subscription product are current.
      // Pass null for eventTimestampMs — sync is a poll, not an event, so it
      // should not advance the watermark or be subject to it (the heal-only
      // guard below provides idempotency).
      await userRepo.setSubscriptionProduct(user.id, product.productId, null);

      // Heal-only credit: only credit if no webhook-issued subscription transaction
      // exists for this user+product. Prevents double-credit when the webhook
      // (INITIAL_PURCHASE / PRODUCT_CHANGE) has already run, while still healing
      // the case where the webhook failed or never fired.
      const hasSubscriptionTx = await userRepo.hasSubscriptionTransactionForProduct(
        user.id, product.productId,
      );
      if (!hasSubscriptionTx) {
        const refId = `sync-heal:${req.user!.googleSub}:${product.productId}`;
        await userRepo.creditQuota(user.id, product.quotaAmount, "subscription", product.productId, refId);
        req.log.info({ user_id: user.id, product_id: productId }, "rc_sync_premium_granted");
      } else {
        req.log.info({ user_id: user.id, product_id: productId }, "rc_sync_already_credited");
      }

      res.json({ synced: true });
    } catch (err) {
      next(err);
    }
  },
);
