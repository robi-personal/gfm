import { Request, Response, NextFunction } from "express";
import { env } from "../../config/env";
import { configService } from "../../config/config-service";
import { killSwitchTrippedTotal } from "../../infrastructure/metrics";

// ── 1. AI_GENERATION_DISABLED ─────────────────────────────────────────────────
export function aiGenerationDisabledMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  if (configService.get<boolean>("AI_GENERATION_DISABLED", env.AI_GENERATION_DISABLED)) {
    req.log.warn({ path: req.path }, "kill_switch_tripped_service_disabled");
    killSwitchTrippedTotal.inc({ which: "ai_generation_disabled" });
    res.status(503).json({
      code: "service_disabled",
      message: "AI generation is temporarily disabled. Please try again later.",
    });
    return;
  }
  next();
}

// ── 2. USER_DENYLIST ──────────────────────────────────────────────────────────
export function denylistMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  const sub = req.user?.googleSub;
  if (sub && env.USER_DENYLIST.has(sub)) {
    req.log.warn({ googleSub: sub, user_id: req.user?.id }, "kill_switch_tripped_user_blocked");
    killSwitchTrippedTotal.inc({ which: "user_blocked" });
    res.status(403).json({
      code: "user_blocked",
      message: "Your account has been suspended.",
    });
    return;
  }
  next();
}
