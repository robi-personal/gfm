import { Request, Response, NextFunction } from "express";
import { env } from "../../config/env";
import { configService } from "../../config/config-service";
import { pool } from "../../infrastructure/db/postgres";
import { PgUserRepository } from "../../infrastructure/db/repositories/pg-user.repository";
import { fetchYoutubeDurationMinutes } from "../../ai/youtube-duration";
import { HttpError } from "./error.middleware";

// Runs after auth on youtube inputType requests.
// 1. Fetches video duration from YouTube Data API.
// 2. Checks monthly minute cap.
// 3. Attaches req.videoDurationMinutes for the route handler to deduct after success.
export async function youtubeMinutesMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const body = req.body as { inputType?: string; youtubeUrl?: string };
  if (body.inputType !== "youtube") {
    next();
    return;
  }

  const cap = configService.get<number>("YOUTUBE_MONTHLY_MINUTES", env.YOUTUBE_MONTHLY_MINUTES);
  if (cap === 0) {
    // Cap of 0 means the feature is fully disabled.
    res.status(503).json({
      code: "youtube_minutes_exceeded",
      message: "YouTube video processing is currently unavailable.",
    });
    return;
  }

  let durationMinutes: number | null = null;
  try {
    durationMinutes = await fetchYoutubeDurationMinutes(body.youtubeUrl ?? "");
  } catch (err) {
    const msg = err instanceof Error ? err.message : "";
    if (msg === "youtube_unavailable") {
      next(new HttpError(400, "youtube_unavailable", "This YouTube video is unavailable or private."));
    } else {
      // API error or missing key — fail open so generation still proceeds.
      req.log?.warn({ err }, "youtube_duration_fetch_failed_failing_open");
      next();
    }
    return;
  }

  // If duration fetch returned null (no API key configured), skip the cap check.
  if (durationMinutes === null) {
    next();
    return;
  }

  try {
    const userRepo = new PgUserRepository(pool);
    await userRepo.resetYoutubeMinutesIfNeeded(req.user!.id);
    const user = await userRepo.findById(req.user!.id);
    if (!user) {
      next(new HttpError(401, "invalid_token", "User not found."));
      return;
    }

    if (user.youtubeMinutesUsed + durationMinutes > cap) {
      const remaining = Math.max(0, cap - user.youtubeMinutesUsed);
      req.log?.warn(
        { userId: req.user!.id, used: user.youtubeMinutesUsed, cap, durationMinutes, remaining },
        "youtube_minutes_exceeded",
      );
      res.status(429).json({
        code: "youtube_minutes_exceeded",
        message: `This video (${durationMinutes} min) would exceed your monthly YouTube limit.`,
        details: {
          used:      user.youtubeMinutesUsed,
          limit:     cap,
          remaining,
          resetsAt:  user.youtubeMinutesResetAt?.toISOString() ?? null,
          videoMinutes: durationMinutes,
        },
      });
      return;
    }

    req.videoDurationMinutes = durationMinutes;
    next();
  } catch (err) {
    req.log?.error({ err }, "youtube_minutes_check_failed");
    next(); // fail open
  }
}
