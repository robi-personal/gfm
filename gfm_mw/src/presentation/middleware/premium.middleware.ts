import { NextFunction, Request, Response } from "express";

/**
 * Reject the request with 403 if the authenticated user is not premium.
 * Must run AFTER authMiddleware. Whitelist users have tier === "premium" too.
 */
export function premiumOnlyMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  if (req.user?.tier !== "premium") {
    res.status(403).json({
      code: "premium_required",
      message: "This feature requires a premium subscription.",
    });
    return;
  }
  next();
}
