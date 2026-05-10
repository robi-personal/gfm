import { Request, Response, NextFunction } from "express";
import * as Sentry from "@sentry/node";
import { verifyGoogleIdToken } from "../../infrastructure/google-auth/google-token-verifier";
import { PgUserRepository } from "../../infrastructure/db/repositories/pg-user.repository";
import { pool } from "../../infrastructure/db/postgres";
import { env } from "../../config/env";

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

    const userRepo = new PgUserRepository(pool);
    const user = await userRepo.upsert(sub, email);

    req.user = {
      id: user.id,
      googleSub: user.googleSub,
      email: user.email,
      tier: (env.RC_BYPASS_PREMIUM || user.isPremium) ? "premium" : "free",
    };

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
