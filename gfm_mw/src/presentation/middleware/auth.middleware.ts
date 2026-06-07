import { Request, Response, NextFunction } from "express";
import * as Sentry from "@sentry/node";
import { verifyGoogleIdToken } from "../../infrastructure/google-auth/google-token-verifier";
import { PgUserRepository } from "../../infrastructure/db/repositories/pg-user.repository";
import { PgQuotaWhitelistRepository } from "../../infrastructure/db/repositories/pg-quota-whitelist.repository";
import { pool } from "../../infrastructure/db/postgres";
import { replayOrphanedEvents } from "../../application/rc-webhook/apply-event";
import { logger } from "../../infrastructure/logger";

export async function authMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const authHeader = req.headers.authorization;

  if (!authHeader?.startsWith("Bearer ")) {
    res.status(401).json({
      code: "invalid_token",
      message: "Missing or invalid Authorization header.",
    });
    return;
  }

  const token = authHeader.slice(7);

  try {
    const { sub, email } = await verifyGoogleIdToken(token);

    const userRepo      = new PgUserRepository(pool);
    const whitelistRepo = new PgQuotaWhitelistRepository(pool);
    const [{ user, created }, isWhitelisted] = await Promise.all([
      userRepo.upsert(sub, email),
      whitelistRepo.contains(email),
    ]);

    // On first sign-in, replay any orphan webhook events that arrived for
    // this google_sub before the user row existed (purchase-flow.md §7 #6).
    // Fire-and-forget so we don't block the request on this slow path.
    if (created) {
      replayOrphanedEvents(sub, user.id).catch((err) => {
        logger.error({ err, user_id: user.id }, "rc_webhook_orphan_replay_unhandled");
      });
    }

    req.user = {
      id: user.id,
      googleSub: user.googleSub,
      email: user.email,
      // Whitelist is treated as a full premium override (unlocks premium-only
      // input types in addition to unlimited quota).
      tier: (user.isPremium || isWhitelisted) ? "premium" : "free",
    };

    // Cancel any pending deletion — signing in means the user is still active.
    // Fire-and-forget so it never adds latency to the auth path.
    userRepo.cancelDeletionIfPending(user.id).catch((err) => {
      logger.error({ err, user_id: user.id }, "cancel_deletion_failed");
    });

    // Re-bind the request logger to include user_id on all subsequent log calls.
    req.log = req.log.child({ user_id: user.id });

    // Tag all subsequent Sentry events in this request with internal user_id.
    Sentry.setUser({ id: String(user.id) });

    next();
  } catch (err) {
    req.log.warn({ err }, "auth_failed");
    res.status(401).json({
      code: "invalid_token",
      message: "Authentication failed. Please sign in again.",
    });
  }
}
