import crypto from "node:crypto";
import { Router } from "express";
import * as Sentry from "@sentry/node";
import { env } from "../../config/env";
import { pool, withTransaction } from "../../infrastructure/db/postgres";
import { DbClient } from "../../infrastructure/db/postgres";
import { PgWebhookEventRepository } from "../../infrastructure/db/repositories/pg-webhook-event.repository";
import { PgUserRepository } from "../../infrastructure/db/repositories/pg-user.repository";
import { rcIpLimitMiddleware } from "../middleware/rate-limit.middleware";
import { rcWebhookTotal, rcWebhookLagMs } from "../../infrastructure/metrics";

export const webhookRouter = Router();

// ── Types ──────────────────────────────────────────────────────────────────────

interface RcEvent {
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
}

interface RcPayload {
  event?: RcEvent;
}

class DuplicateEventError extends Error {}

// ── Utilities ──────────────────────────────────────────────────────────────────

function msToDate(ms: number | null | undefined): Date | null {
  return ms != null ? new Date(ms) : null;
}

// ── Event handlers (see revenuecat-webhook-map.md §3) ─────────────────────────

async function applyEvent(db: DbClient, userId: number, event: RcEvent): Promise<void> {
  const userRepo = new PgUserRepository(db);

  switch (event.type) {
    case "INITIAL_PURCHASE": {
      const resetAt = msToDate(event.expiration_at_ms);
      if (resetAt) await userRepo.setPremium(userId, resetAt);
      break;
    }
    case "RENEWAL": {
      const resetAt = msToDate(event.expiration_at_ms);
      if (resetAt) await userRepo.renewPremium(userId, resetAt);
      break;
    }
    case "CANCELLATION":
      // No user update — subscription still active until expiration_at_ms.
      // Access is revoked by the EXPIRATION event. (§3.3)
      break;
    case "EXPIRATION": {
      // revokePremium uses the "only-revoke-if-not-already-renewed" guard (§3.4).
      const expiresAt = msToDate(event.expiration_at_ms) ?? new Date();
      await userRepo.revokePremium(userId, expiresAt);
      break;
    }
    case "BILLING_ISSUE": {
      // GREATEST guard in setGracePeriod prevents duplicate events from shrinking window (§3.5).
      const gracePeriodUntil = event.grace_period_expiration_at_ms
        ? msToDate(event.grace_period_expiration_at_ms)!
        : new Date(Date.now() + 16 * 24 * 60 * 60 * 1_000);
      await userRepo.setGracePeriod(userId, gracePeriodUntil);
      break;
    }
    case "REFUND":
      // Revoke immediately regardless of billing period (§3.6).
      await userRepo.revokeImmediately(userId);
      break;
    case "PRODUCT_CHANGE": {
      const stillPremium = event.entitlement_ids?.includes("gfm_premium") ?? false;
      const resetAt = msToDate(event.expiration_at_ms) ?? new Date();
      // ai_premium_used intentionally NOT reset — quota continues across plan changes (§3.7).
      await userRepo.updateProductChange(userId, stillPremium, resetAt);
      break;
    }
    case "TRANSFER":
      // transferred_from/to are google_sub arrays; updates go directly via those arrays (§4.4).
      if (event.transferred_from?.length) {
        await userRepo.transferFrom(event.transferred_from);
      }
      if (event.transferred_to?.length) {
        await userRepo.transferTo(event.transferred_to);
      }
      break;
    default:
      // Unknown event type — row is already stored by the common pipeline.
      // Forward-compatible: new RC event types are stored and acked without error.
      break;
  }
}

// ── Route ──────────────────────────────────────────────────────────────────────

webhookRouter.post(
  "/revenuecat",
  rcIpLimitMiddleware,
  async (req, res) => {
    // Step 1: Verify HMAC — raw body must be captured before express.json parses it.
    // app.ts sets express.json({ verify }) to save req.rawBody for this purpose.
    const rawBody = req.rawBody;
    if (!rawBody) {
      res.status(400).json({ code: "invalid_input", message: "Missing raw body." });
      return;
    }

    const computed = crypto
      .createHmac("sha256", env.RC_WEBHOOK_SECRET)
      .update(rawBody)
      .digest("hex");
    const provided = req.headers.authorization ?? "";

    const computedBuf = Buffer.from(computed);
    const providedBuf = Buffer.from(provided);
    const sigValid =
      computedBuf.length === providedBuf.length &&
      crypto.timingSafeEqual(computedBuf, providedBuf);

    if (!sigValid) {
      req.log.error({ path: req.path }, "rc_hmac_mismatch");
      Sentry.withScope((scope) => {
        scope.setLevel("warning");
        scope.setTag("route", "POST /webhooks/revenuecat");
        Sentry.captureException(new Error("rc_webhook_hmac_mismatch"));
      });
      res.status(401).json({
        code: "invalid_signature",
        message: "Webhook signature verification failed.",
      });
      return;
    }

    // Step 2: Parse envelope
    const payload = req.body as RcPayload;
    const event   = payload?.event;
    if (!event?.id || !event?.type) {
      res.status(400).json({
        code: "invalid_input",
        message: "Malformed RevenueCat event payload.",
      });
      return;
    }

    const purchasedAtMs =
      typeof (payload as unknown as { event?: { purchased_at_ms?: unknown } }).event?.purchased_at_ms === "number"
        ? ((payload as unknown as { event: { purchased_at_ms: number } }).event.purchased_at_ms)
        : null;
    const isSandbox = event.environment === "SANDBOX";

    const recordWebhookMetric = (outcome: string): void => {
      rcWebhookTotal.inc({ event_type: event.type, outcome });
      if (purchasedAtMs) rcWebhookLagMs.observe(Date.now() - purchasedAtMs);
    };

    // Step 3: Fast dedupe pre-check (authoritative guard is the UNIQUE constraint in Step 6)
    const webhookRepo = new PgWebhookEventRepository(pool);
    if (await webhookRepo.existsById(event.id)) {
      req.log.info(
        { event_id: event.id, type: event.type, is_duplicate: true, is_sandbox: isSandbox },
        "rc_webhook_duplicate_skipped",
      );
      recordWebhookMetric("duplicate");
      res.json({ received: true });
      return;
    }

    // Step 4: Sandbox gate — store for audit but skip user updates in production (§4.3)
    if (isSandbox && env.NODE_ENV === "production") {
      await webhookRepo.insertIfAbsent(event.id, event.type, null, payload);
      req.log.info(
        { event_id: event.id, type: event.type, is_sandbox: true },
        "rc_webhook_sandbox_stored_noop",
      );
      recordWebhookMetric("sandbox_skipped");
      res.json({ received: true });
      return;
    }

    // Step 5: Resolve user — RC app_user_id == google_sub stored at sign-in
    const userRepo = new PgUserRepository(pool);
    const user     = await userRepo.findByGoogleSub(event.app_user_id);
    if (!user) {
      // Config drift — store for audit, ack 200 so RC doesn't retry forever (§4.5)
      await webhookRepo.insertIfAbsent(event.id, event.type, null, payload);
      req.log.warn(
        { event_id: event.id, type: event.type, app_user_id: event.app_user_id },
        "rc_webhook_unknown_user",
      );
      recordWebhookMetric("unknown_user");
      res.json({ received: true });
      return;
    }

    // Step 6: Apply event in a transaction — webhook_events INSERT + users UPDATE atomically
    try {
      await withTransaction(async (tx) => {
        const txWebhookRepo = new PgWebhookEventRepository(tx);
        const { inserted }  = await txWebhookRepo.insertIfAbsent(
          event.id, event.type, user.id, payload,
        );
        // rowCount 0 means a concurrent worker beat us — roll back and ack silently
        if (!inserted) throw new DuplicateEventError();

        await applyEvent(tx, user.id, event);
      });
    } catch (err) {
      if (err instanceof DuplicateEventError) {
        req.log.info({ event_id: event.id }, "rc_webhook_duplicate_concurrent_skipped");
        recordWebhookMetric("duplicate");
        res.json({ received: true });
        return;
      }
      // DB failure — return 5xx so RC retries (self-healing on transient outages §4.7)
      req.log.error({ err, event_id: event.id }, "rc_webhook_transaction_failed");
      recordWebhookMetric("error");
      res.status(503).json({
        code: "database_unavailable",
        message: "Database is temporarily unavailable. Please retry.",
      });
      return;
    }

    req.log.info(
      {
        event_id: event.id,
        event_type: event.type,
        user_id: user.id,
        is_sandbox: isSandbox,
        is_duplicate: false,
        rc_event_at_ms: purchasedAtMs,
        webhook_lag_ms: purchasedAtMs ? Date.now() - purchasedAtMs : null,
      },
      "rc_webhook_processed",
    );
    recordWebhookMetric("processed");
    res.json({ received: true });
  },
);
