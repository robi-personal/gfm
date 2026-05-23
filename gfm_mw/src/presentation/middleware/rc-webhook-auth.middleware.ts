import { Request, Response, NextFunction } from "express";
import crypto from "node:crypto";
import * as Sentry from "@sentry/node";
import { env } from "../../config/env";

/**
 * Bearer-secret check for POST /webhooks/revenuecat.
 *
 * Mounted BEFORE the IP rate limiter so forged traffic gets 401 without
 * consuming the limiter budget — RC ships from a small IP pool, and if a
 * spammer ate into the same budget they could push out legitimate RC
 * traffic. See purchase-flow.md §7 *Outstanding* #2.
 *
 * Constant-time compare via timingSafeEqual; matches RC's documented
 * Authorization-header integration.
 */
export function rcWebhookAuthMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  const provided = req.headers.authorization ?? "";
  const expected = env.RC_WEBHOOK_SECRET;

  const providedBuf = Buffer.from(provided);
  const expectedBuf = Buffer.from(expected);
  const sigValid =
    providedBuf.length === expectedBuf.length &&
    crypto.timingSafeEqual(providedBuf, expectedBuf);

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

  next();
}
