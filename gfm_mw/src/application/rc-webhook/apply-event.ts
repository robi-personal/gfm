import { pool, DbClient, withTransaction } from "../../infrastructure/db/postgres";
import { PgUserRepository } from "../../infrastructure/db/repositories/pg-user.repository";
import { PgQuotaProductRepository } from "../../infrastructure/db/repositories/pg-quota-product.repository";
import { PgWebhookEventRepository } from "../../infrastructure/db/repositories/pg-webhook-event.repository";
import { logger } from "../../infrastructure/logger";

// ── Types ──────────────────────────────────────────────────────────────────────

export interface RcEvent {
  id: string;
  type: string;
  app_user_id: string;
  entitlement_ids?: string[];
  product_id?: string;
  expiration_at_ms?: number | null;
  environment: "PRODUCTION" | "SANDBOX";
  grace_period_expiration_at_ms?: number;
  transferred_from?: string[];
  transferred_to?: string[];
  event_timestamp_ms?: number;
  purchased_at_ms?: number;
}

export interface RcPayload {
  event?: RcEvent;
}

// ── Utilities ──────────────────────────────────────────────────────────────────

function msToDate(ms: number | null | undefined): Date | null {
  return ms != null ? new Date(ms) : null;
}

// Watermark for out-of-order RC delivery (see purchase-flow.md §6.3).
// Prefer event_timestamp_ms (when RC fired the event); fall back to
// purchased_at_ms (transaction time). Both may be absent on some event
// shapes — then we pass null and the repository skips the watermark check.
export function eventWatermark(event: RcEvent): number | null {
  return event.event_timestamp_ms ?? event.purchased_at_ms ?? null;
}

// ── Handler ───────────────────────────────────────────────────────────────────
// See revenuecat-webhook-map.md §3 for per-event semantics and
// purchase-flow.md §6.1/§6.3 for the dedupe + watermark contracts.

export async function applyEvent(
  db: DbClient,
  userId: number,
  event: RcEvent,
): Promise<void> {
  const userRepo    = new PgUserRepository(db);
  const productRepo = new PgQuotaProductRepository(pool);
  const ts          = eventWatermark(event);

  switch (event.type) {
    case "INITIAL_PURCHASE": {
      if (!event.product_id) {
        logger.error(
          { event_id: event.id, app_user_id: event.app_user_id },
          "rc_initial_purchase_missing_product_id",
        );
        break;
      }
      const product = await productRepo.getById(event.product_id);
      if (!product) {
        logger.warn({ product_id: event.product_id }, "rc_webhook_unknown_product");
        break;
      }
      // Atomic — second caller (sync) sees is_premium=true and short-circuits.
      await userRepo.claimPremiumAndCredit(
        userId, product.quotaAmount, product.productId, "subscription", event.id, ts,
      );
      break;
    }
    case "RENEWAL": {
      if (!event.product_id) break;
      const product = await productRepo.getById(event.product_id);
      if (!product) {
        logger.warn({ product_id: event.product_id }, "rc_webhook_unknown_product");
        break;
      }
      await userRepo.creditQuota(userId, product.quotaAmount, "subscription", product.productId, event.id);
      await userRepo.setSubscriptionProduct(userId, product.productId, ts);
      // Successful renewal clears any prior grace period.
      await userRepo.clearGracePeriod(userId, ts);
      break;
    }
    case "NON_RENEWING_PURCHASE": {
      if (!event.product_id) break;
      const product = await productRepo.getById(event.product_id);
      if (!product) {
        logger.warn({ product_id: event.product_id }, "rc_webhook_unknown_product");
        break;
      }
      // Top-ups don't affect premium status or watermark — pure credit.
      await userRepo.creditQuota(userId, product.quotaAmount, "topup", product.productId, event.id);
      break;
    }
    case "CANCELLATION":
      // No action — subscription stays active until EXPIRATION.
      break;
    case "EXPIRATION":
      // Balance rolls forward; just clear premium status.
      await userRepo.setSubscriptionProduct(userId, null, ts);
      break;
    case "BILLING_ISSUE": {
      const gracePeriodUntil = event.grace_period_expiration_at_ms
        ? msToDate(event.grace_period_expiration_at_ms)!
        : new Date(Date.now() + 16 * 24 * 60 * 60 * 1_000);
      await userRepo.setGracePeriod(userId, gracePeriodUntil, ts);
      break;
    }
    case "REFUND":
      // Revoke premium immediately. Balance is NOT clawed back —
      // audit trail in quota_transactions. revokeImmediately clears
      // subscription_product_id too.
      await userRepo.revokeImmediately(userId, ts);
      break;
    case "PRODUCT_CHANGE": {
      const stillPremium = event.entitlement_ids?.includes("GFMPremium") ?? false;
      await userRepo.updateProductChange(userId, stillPremium, ts);
      if (event.product_id) {
        const product = await productRepo.getById(event.product_id);
        if (!product) {
          logger.warn({ product_id: event.product_id }, "rc_webhook_unknown_product");
        } else {
          // Heal-only credit. Mirrors the sync side's check (user.routes.ts)
          // so the sync-first/webhook-second race can't double-credit. The
          // partial UNIQUE on quota_transactions doesn't catch this on its
          // own because sync writes source='subscription' and we'd write
          // source='subscription_upgrade' — different rows, no conflict.
          const already = await userRepo.hasSubscriptionTransactionForProduct(
            userId, product.productId,
          );
          if (!already) {
            await userRepo.creditQuota(userId, product.quotaAmount, "subscription_upgrade", product.productId, event.id);
          }
        }
        await userRepo.setSubscriptionProduct(userId, event.product_id, ts);
      }
      break;
    }
    case "TRANSFER":
      if (event.transferred_from?.length) {
        await userRepo.transferFrom(event.transferred_from, ts);
      }
      if (event.transferred_to?.length) {
        await userRepo.transferTo(event.transferred_to, event.product_id ?? null, ts);
      }
      break;
    default:
      break;
  }
}

// ── Orphan replay (purchase-flow.md §7 #6) ────────────────────────────────────
// Called by auth.middleware on first sign-in. Applies any webhook_events that
// arrived for this user before the row existed, then claims them by setting
// user_id. Fire-and-forget from the caller's perspective: failures are logged
// but do not block the request.

export async function replayOrphanedEvents(googleSub: string, userId: number): Promise<void> {
  const webhookRepo = new PgWebhookEventRepository(pool);
  const orphans = await webhookRepo.listOrphanedForGoogleSub(googleSub);
  if (orphans.length === 0) return;

  logger.info(
    { user_id: userId, app_user_id: googleSub, count: orphans.length },
    "rc_webhook_orphan_replay_start",
  );

  for (const orphan of orphans) {
    const event = (orphan.rawPayload as RcPayload)?.event;
    if (!event) continue;
    try {
      await withTransaction(async (tx) => {
        await applyEvent(tx, userId, event);
        const txWebhookRepo = new PgWebhookEventRepository(tx);
        await txWebhookRepo.claimForUser(orphan.eventId, userId);
      });
      logger.info(
        { user_id: userId, event_id: orphan.eventId, type: orphan.eventType },
        "rc_webhook_orphan_replayed",
      );
    } catch (err) {
      // Don't bail on a single bad event — try the rest. The row stays
      // user_id=NULL so a future replay can retry it.
      logger.error(
        { err, user_id: userId, event_id: orphan.eventId },
        "rc_webhook_orphan_replay_failed",
      );
    }
  }
}
