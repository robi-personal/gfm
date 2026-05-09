import { Request, Response, NextFunction } from "express";
import { env } from "../../config/env";

export function adminAuthMiddleware(req: Request, res: Response, next: NextFunction): void {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    res.status(401).json({ code: "unauthorized", message: "Missing or invalid authorization." });
    return;
  }
  const token = header.slice(7);
  if (token !== env.ADMIN_TOKEN) {
    res.status(403).json({ code: "forbidden", message: "Invalid admin token." });
    return;
  }
  next();
}
