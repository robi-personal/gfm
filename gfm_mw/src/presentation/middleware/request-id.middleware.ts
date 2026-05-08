import { Request, Response, NextFunction } from "express";
import { v4 as uuidv4 } from "uuid";

export function requestIdMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  const existing = req.headers["x-request-id"];
  req.id = (Array.isArray(existing) ? existing[0] : existing) ?? uuidv4();
  res.setHeader("X-Request-Id", req.id);
  next();
}
