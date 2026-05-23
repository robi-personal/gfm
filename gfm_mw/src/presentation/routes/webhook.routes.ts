import { Router } from "express";
import { env } from "../../config/env";
import { configService } from "../../config/config-service";
import { pool, withTransaction } from "../../infrastructure/db/postgres";
import { PgWebhookEventRepository } from "../../infrastructure/db/repositories/pg-webhook-event.repository";
import { PgUserRepository } from "../../infrastructure/db/repositories/pg-user.repository";
import { PgFormWatchRepository } from "../../infrastructure/db/repositories/pg-form-watch.repository";
import { PgDeviceTokenRepository } from "../../infrastructure/db/repositories/pg-device-token.repository";
import { rcIpLimitMiddleware } from "../middleware/rate-limit.middleware";
import { rcWebhookAuthMiddleware } from "../middleware/rc-webhook-auth.middleware";
import { rcWebhookTotal, rcWebhookLagMs } from "../../infrastructure/metrics";
import { verifyPubsubOidcToken } from "../../infrastructure/google-auth/pubsub-token-verifier";
import { sendToTokens } from "../../infrastructure/fcm/fcm.service";
import { applyEvent, RcPayload } from "../../application/rc-webhook/apply-event";

export const webhookRouter = Router();

class DuplicateEventError extends Error {}

// ── Route ──────────────────────────────────────────────────────────────────────
// Middleware order matters: bearer auth runs BEFORE the rate limit so a
// spammer hitting this URL cannot eat into the per-IP budget that RC's own
// (small) IP pool needs. See purchase-flow.md §7 *Outstanding* #2.

webhookRouter.post(
  "/revenuecat",
  rcWebhookAuthMiddleware,
  rcIpLimitMiddleware,
  async (req, res) => {
    const rawBody = req.rawBody;
    if (!rawBody) {
      res.status(400).json({ code: "invalid_input", message: "Missing raw body." });
      return;
    }

    // Parse envelope
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

    // Sandbox events are processed identically to production — accepted by
    // explicit decision during pre-launch + solo-dev testing. Re-introduce
    // a gate (env flag or NODE_ENV check) before opening the app to public
    // sign-ups so external sandbox Apple IDs can't credit real quota.

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

    // Step 4: Resolve user — RC app_user_id == google_sub stored at sign-in
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

// ── Pub/Sub push handler: new form responses ──────────────────────────────────
// Google Forms watches publish a message to our Pub/Sub topic when a new
// response is submitted. Pub/Sub then POSTs that message to this endpoint as a
// push subscription. The message includes the formId in its attributes; we
// look up the user that owns the watch, fetch their FCM tokens, and send a push.
//
// See SESSION_CONTEXT — push-notification feature, Session 1.

interface PubsubPushBody {
  message?: {
    messageId?: string;
    data?: string;
    attributes?: Record<string, string>;
    publishTime?: string;
  };
  subscription?: string;
}

webhookRouter.post("/forms-watch", async (req, res) => {
  // 1. Verify OIDC token from Pub/Sub. We do this even in dev (Google Pub/Sub
  //    will refuse to deliver without one once configured).
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith("Bearer ")) {
    res.status(401).json({ code: "missing_oidc", message: "Missing Bearer token." });
    return;
  }
  try {
    await verifyPubsubOidcToken(authHeader.slice("Bearer ".length));
  } catch (err) {
    req.log.warn({ err }, "pubsub_oidc_invalid");
    res.status(401).json({ code: "invalid_oidc", message: "OIDC verification failed." });
    return;
  }

  // 2. Parse Pub/Sub envelope.
  const body = req.body as PubsubPushBody;
  const message = body.message;
  if (!message?.messageId) {
    res.status(400).json({ code: "invalid_envelope", message: "Missing message." });
    return;
  }

  const formId = message.attributes?.formId;
  const eventType = message.attributes?.eventType ?? "RESPONSES";
  if (!formId) {
    // Without a formId we can't route. Ack so Pub/Sub stops retrying.
    req.log.warn({ messageId: message.messageId }, "pubsub_message_missing_formId");
    res.status(204).end();
    return;
  }

  // 3. Idempotency: skip if we've already processed this messageId.
  const watchRepo = new PgFormWatchRepository(pool);
  if (await watchRepo.isMessageProcessed(message.messageId)) {
    req.log.info({ messageId: message.messageId }, "pubsub_duplicate_message");
    res.status(204).end();
    return;
  }

  // 4. Route: formId → watch → user → device tokens.
  const watches = await watchRepo.listByFormId(formId);
  if (watches.length === 0) {
    // Watch may have been deleted or expired. Mark processed and ack.
    await watchRepo.markMessageProcessed(message.messageId);
    req.log.info({ formId }, "pubsub_no_active_watch");
    res.status(204).end();
    return;
  }

  // 5. For each watch (usually one row per form), send push to user's devices.
  const deviceRepo = new PgDeviceTokenRepository(pool);
  const titleTemplate = configService.get<string>(
    "NOTIFICATION_TITLE_TEMPLATE",
    env.NOTIFICATION_TITLE_TEMPLATE,
  );
  const bodyTemplate = configService.get<string>(
    "NOTIFICATION_BODY_TEMPLATE",
    env.NOTIFICATION_BODY_TEMPLATE,
  );

  for (const watch of watches) {
    const tokens = await deviceRepo.listByUserId(watch.userId);
    if (tokens.length === 0) continue;

    const fillTemplate = (tpl: string): string =>
      tpl.replaceAll("{formTitle}", watch.formTitle || "your form");
    const title = fillTemplate(titleTemplate);
    const bodyText = fillTemplate(bodyTemplate);

    try {
      const result = await sendToTokens(
        tokens.map((t) => t.fcmToken),
        title,
        bodyText,
        { formId, eventType, watchId: watch.watchId },
      );
      if (result.invalidTokens.length > 0) {
        await deviceRepo.deleteMany(result.invalidTokens);
      }
      req.log.info(
        {
          formId,
          userId: watch.userId,
          success: result.successCount,
          failure: result.failureCount,
        },
        "fcm_push_sent",
      );
    } catch (err) {
      req.log.error({ err, formId, userId: watch.userId }, "fcm_push_failed");
      // Don't ack — let Pub/Sub retry.
      res.status(503).json({ code: "fcm_error", message: "FCM send failed." });
      return;
    }
  }

  await watchRepo.markMessageProcessed(message.messageId);
  res.status(204).end();
});
