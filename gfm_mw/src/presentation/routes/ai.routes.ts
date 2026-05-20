import { Router, Request, Response, NextFunction } from "express";
import { v4 as uuidv4 } from "uuid";
import { authMiddleware } from "../middleware/auth.middleware";
import {
  denylistMiddleware,
} from "../middleware/kill-switch.middleware";
import {
  aiUserHourlyLimitMiddleware,
  aiUserDailyLimitMiddleware,
} from "../middleware/rate-limit.middleware";
import { HttpError } from "../middleware/error.middleware";
import { pool } from "../../infrastructure/db/postgres";
import { env } from "../../config/env";
import { PgAiGenerationRepository } from "../../infrastructure/db/repositories/pg-ai-generation.repository";
import { PgUserRepository } from "../../infrastructure/db/repositories/pg-user.repository";
import { PgQuotaWhitelistRepository } from "../../infrastructure/db/repositories/pg-quota-whitelist.repository";
import { PgQuotaProductRepository } from "../../infrastructure/db/repositories/pg-quota-product.repository";
import {
  GenerateRequest,
  decodedBase64Bytes,
  MAX_DECODED_BYTES,
} from "../../ai/request-schema";
import { hashRequestBody } from "../../ai/canonicalize";
import { runGeneration } from "../../ai/generator";
import { countPdfPages, pdfQuotaCost } from "../../ai/pdf-pages";
import { quotaExceededTotal } from "../../infrastructure/metrics";
import { youtubeMinutesMiddleware } from "../middleware/youtube-minutes.middleware";
import { configService } from "../../config/config-service";

const UUIDV4_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

interface QuotaSnapshot {
  balance: number;
  quotaCost: number;
  unlimited: boolean;
  youtubeMinutesUsed: number;
  youtubeMinutesLimit: number;
  youtubeMinutesResetsAt: string | null;
}

async function getQuotaSnapshot(
  userRepo: PgUserRepository,
  whitelistRepo: PgQuotaWhitelistRepository,
  userId: number,
  email: string,
  quotaCost: number,
): Promise<QuotaSnapshot> {
  const user = await userRepo.findById(userId);
  if (!user) {
    throw new HttpError(401, "invalid_token", "User not found.");
  }
  const ytLimit = configService.get<number>("YOUTUBE_MONTHLY_MINUTES", env.YOUTUBE_MONTHLY_MINUTES);
  const ytBase = {
    youtubeMinutesUsed:    user.youtubeMinutesUsed,
    youtubeMinutesLimit:   ytLimit,
    youtubeMinutesResetsAt: user.youtubeMinutesResetAt?.toISOString() ?? null,
  };

  const unlimited = await whitelistRepo.contains(email);
  if (unlimited) {
    return { balance: 0, quotaCost, unlimited: true, ...ytBase };
  }

  return {
    balance:   user.quotaBalance,
    quotaCost,
    unlimited: false,
    ...ytBase,
  };
}

function premiumOnlyInputType(t: string): boolean {
  return t === "pdf" || t === "youtube" || t === "urls" || t === "book";
}

function inputSizeBytes(body: GenerateRequest): number | undefined {
  switch (body.inputType) {
    case "text":    return Buffer.byteLength(body.prompt, "utf8");
    case "pdf":     return decodedBase64Bytes(body.fileBase64);
    case "book":    return decodedBase64Bytes(body.fileBase64);
    case "youtube": return body.youtubeUrl.length;
    case "urls":    return body.urls.reduce((sum, u) => sum + u.length, 0);
  }
}

export const aiRouter = Router();

// ── Pre-flight: count pages + quota cost for pdf/book inputs ──────────────────
aiRouter.post(
  "/pdf-page-count",
  authMiddleware,
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { fileBase64, inputType } = req.body as { fileBase64?: unknown; inputType?: unknown };
      if (typeof fileBase64 !== "string" || !fileBase64) {
        throw new HttpError(400, "invalid_input", "fileBase64 is required.");
      }
      if (inputType !== "pdf" && inputType !== "book") {
        throw new HttpError(400, "invalid_input", "inputType must be pdf or book.");
      }

      const pages       = await countPdfPages(fileBase64);
      const pagesPerQuota = configService.get<number>("PDF_PAGES_PER_QUOTA", env.PDF_PAGES_PER_QUOTA);
      const quotaCost   = pdfQuotaCost(pages, pagesPerQuota);

      res.json({ pages, quotaCost, pagesPerQuota });
    } catch (err) {
      next(err);
    }
  },
);

aiRouter.post(
  "/generate",
  authMiddleware,
  denylistMiddleware,
  aiUserHourlyLimitMiddleware,
  aiUserDailyLimitMiddleware,
  youtubeMinutesMiddleware,
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      // ── 1. Idempotency-Key header validation ──────────────────────────────
      const rawKey = req.headers["idempotency-key"];
      const idempotencyKey = Array.isArray(rawKey) ? rawKey[0] : rawKey;
      if (!idempotencyKey || typeof idempotencyKey !== "string") {
        throw new HttpError(400, "missing_idempotency_key", "Idempotency-Key header is required.");
      }
      if (!UUIDV4_RE.test(idempotencyKey)) {
        throw new HttpError(400, "missing_idempotency_key", "Idempotency-Key must be a UUIDv4.");
      }

      // ── 2. Body Zod validation ────────────────────────────────────────────
      const parsed = GenerateRequest.safeParse(req.body);
      if (!parsed.success) {
        const inputTypeIssue = parsed.error.issues.find(
          (i) => i.path[0] === "inputType",
        );
        if (inputTypeIssue) {
          throw new HttpError(400, "unsupported_input_type", "Unsupported inputType.", {
            inputType: typeof req.body?.inputType === "string" ? req.body.inputType : null,
          });
        }
        throw new HttpError(400, "invalid_input", "Request validation failed.", {
          issues: parsed.error.issues.map((i) => ({
            path: i.path,
            message: i.message,
          })),
        });
      }
      const body = parsed.data;

      // ── 3. File size cap (decoded bytes) for pdf/book ─────────────────────
      let quotaCost = 1;
      if (body.inputType === "pdf" || body.inputType === "book") {
        const bytes = decodedBase64Bytes(body.fileBase64);
        if (bytes > MAX_DECODED_BYTES) {
          throw new HttpError(400, "file_too_large", "File exceeds the 5 MB limit.", {
            maxBytes: MAX_DECODED_BYTES,
            actualBytes: bytes,
          });
        }
        const pages         = await countPdfPages(body.fileBase64);
        const pagesPerQuota = configService.get<number>("PDF_PAGES_PER_QUOTA", env.PDF_PAGES_PER_QUOTA);
        quotaCost           = pdfQuotaCost(pages, pagesPerQuota);

        if (body.confirmedQuotaCost !== quotaCost) {
          throw new HttpError(409, "quota_cost_changed",
            `The quota cost changed (was ${body.confirmedQuotaCost}, now ${quotaCost}). Please try again.`,
            { confirmedQuotaCost: body.confirmedQuotaCost, actualQuotaCost: quotaCost },
          );
        }
      }

      // ── 4. Hash canonical body for idempotency cache ──────────────────────
      const requestHash = hashRequestBody(body);

      const aiRepo        = new PgAiGenerationRepository(pool);
      const userRepo      = new PgUserRepository(pool);
      const whitelistRepo = new PgQuotaWhitelistRepository(pool);

      // ── 5. Whitelist check ────────────────────────────────────────────────
      const isWhitelisted = await whitelistRepo.contains(req.user!.email);

      // ── 6. Resolve idempotency state ──────────────────────────────────────
      const existing = await aiRepo.findByIdempotencyKey(req.user!.id, idempotencyKey);

      if (existing) {
        if (existing.requestHash !== requestHash) {
          throw new HttpError(409, "idempotency_conflict",
            "This Idempotency-Key was used with a different request body. Use a fresh key.",
            { originalRequestHash: existing.requestHash },
          );
        }
        if (existing.status === "success") {
          const quota = await getQuotaSnapshot(userRepo, whitelistRepo, req.user!.id, req.user!.email, quotaCost);
          res.json({
            generationId: existing.generationId,
            status:       "completed",
            form:         existing.outputJson,
            tokensUsed:   { input: existing.inputTokens ?? 0, output: existing.outputTokens ?? 0 },
            quota,
          });
          return;
        }
        if (existing.status === "processing") {
          const ageMs = Date.now() - existing.createdAt.getTime();
          if (ageMs < 2 * 60 * 1_000) {
            throw new HttpError(409, "idempotency_in_flight",
              "Your previous request is still being processed. Please retry in a moment.");
          }
          req.log.warn({ generationId: existing.generationId, ageMs }, "idempotency_stuck_processing_takeover");
        }
      }

      // ── 7. Premium gate (free users blocked from non-text inputs) ─────────
      if (req.user!.tier === "free" && premiumOnlyInputType(body.inputType)) {
        throw new HttpError(403, "premium_required",
          "This input type requires a premium subscription.",
          { requiredEntitlement: "GFMPremium", requestedInputType: body.inputType },
        );
      }

      // ── 8. Quota gate (skipped for whitelisted users) ─────────────────────
      if (!isWhitelisted) {
        const productRepo = new PgQuotaProductRepository(pool);
        const freeProduct = await productRepo.getById("free");
        if (freeProduct) {
          await userRepo.applyFreeGrantIfDue(req.user!.id, freeProduct);
        }

        const balance = await userRepo.getQuotaBalance(req.user!.id);
        if (balance < quotaCost) {
          quotaExceededTotal.inc({ tier: req.user!.tier });
          throw new HttpError(429, "quota_exceeded",
            `This request costs ${quotaCost} quota but you only have ${balance} remaining.`,
            {
              tier:      req.user!.tier,
              balance,
              quotaCost,
            },
          );
        }
      }

      // ── 9. Claim a row to own ─────────────────────────────────────────────
      let rowId: number;
      let generationId: string;

      if (existing) {
        const claimed = await aiRepo.claimFailedForRetry(existing.id);
        if (!claimed) {
          throw new HttpError(409, "idempotency_in_flight",
            "Another retry took over this request. Please retry in a moment.");
        }
        rowId        = existing.id;
        generationId = existing.generationId;
      } else {
        const newGenerationId = uuidv4();
        const created = await aiRepo.tryCreate({
          generationId:   newGenerationId,
          userId:         req.user!.id,
          idempotencyKey,
          requestHash,
          inputType:      body.inputType,
          inputSize:      inputSizeBytes(body),
        });

        if (created) {
          rowId        = created.id;
          generationId = created.generationId;
        } else {
          const racingRow = await aiRepo.findByIdempotencyKey(req.user!.id, idempotencyKey);
          if (!racingRow) {
            throw new HttpError(503, "database_unavailable", "Please retry.");
          }
          if (racingRow.requestHash !== requestHash) {
            throw new HttpError(409, "idempotency_conflict",
              "This Idempotency-Key was used with a different request body. Use a fresh key.",
              { originalRequestHash: racingRow.requestHash },
            );
          }
          if (racingRow.status === "success") {
            const quota = await getQuotaSnapshot(userRepo, whitelistRepo, req.user!.id, req.user!.email, quotaCost);
            res.json({
              generationId: racingRow.generationId,
              status:       "completed",
              form:         racingRow.outputJson,
              tokensUsed:   { input: racingRow.inputTokens ?? 0, output: racingRow.outputTokens ?? 0 },
              quota,
            });
            return;
          }
          throw new HttpError(409, "idempotency_in_flight",
            "Your previous request is still being processed. Please retry in a moment.");
        }
      }

      // ── 10. Run the Gemini pipeline ────────────────────────────────────────
      const outcome = await runGeneration({
        user:    { id: req.user!.id, tier: req.user!.tier },
        body,
        rowId,
        generationId,
        quotaCost,
        aiRepo,
        userRepo,
        log: req.log,
      });

      req.geminiInputTokens  = outcome.inputTokens;
      req.geminiOutputTokens = outcome.outputTokens;

      // ── 11. Deduct quota (non-whitelisted users only) ──────────────────────
      if (!isWhitelisted) {
        await userRepo.debitQuota(req.user!.id, quotaCost, outcome.generationId);
      }

      // ── 12. Deduct YouTube minutes if applicable ───────────────────────────
      if (req.videoDurationMinutes) {
        await userRepo.incrementYoutubeMinutes(req.user!.id, req.videoDurationMinutes);
      }

      // ── 13. Respond with success + fresh quota snapshot ────────────────────
      const quotaAfter = await getQuotaSnapshot(userRepo, whitelistRepo, req.user!.id, req.user!.email, quotaCost);
      res.json({
        generationId: outcome.generationId,
        status:       "completed",
        form:         outcome.form,
        tokensUsed:   { input: outcome.inputTokens, output: outcome.outputTokens },
        quotaCost,
        quota:        quotaAfter,
      });
    } catch (err) {
      next(err);
    }
  },
);
