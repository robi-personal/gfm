import { Router, Request, Response, NextFunction } from "express";
import { v4 as uuidv4 } from "uuid";
import { authMiddleware } from "../middleware/auth.middleware";
import {
  denylistMiddleware,
  perUserBudgetMiddleware,
  dailyBudgetMiddleware,
} from "../middleware/kill-switch.middleware";
import {
  aiUserHourlyLimitMiddleware,
  aiUserDailyLimitMiddleware,
} from "../middleware/rate-limit.middleware";
import { HttpError } from "../middleware/error.middleware";
import { pool } from "../../infrastructure/db/postgres";
import { PgAiGenerationRepository } from "../../infrastructure/db/repositories/pg-ai-generation.repository";
import { PgUserRepository } from "../../infrastructure/db/repositories/pg-user.repository";
import {
  GenerateRequest,
  decodedBase64Bytes,
  MAX_DECODED_BYTES,
} from "../../ai/request-schema";
import { hashRequestBody } from "../../ai/canonicalize";
import { runGeneration } from "../../ai/generator";

const FREE_LIMIT    = 3;
const PREMIUM_LIMIT = 50;

const UUIDV4_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

interface QuotaSnapshot {
  tier: "free" | "premium";
  used: number;
  limit: number;
  resetsAt: string;
}

async function getQuotaSnapshot(
  userRepo: PgUserRepository,
  userId: number,
): Promise<QuotaSnapshot> {
  const user = await userRepo.findById(userId);
  if (!user) {
    // Should never happen — auth just upserted this user.
    throw new HttpError(401, "invalid_token", "User not found.");
  }
  if (user.isPremium) {
    return {
      tier: "premium",
      used: user.aiPremiumUsed,
      limit: PREMIUM_LIMIT,
      resetsAt: (user.premiumResetAt ?? new Date(Date.now() + 30 * 24 * 60 * 60 * 1_000)).toISOString(),
    };
  }
  return {
    tier: "free",
    used: user.aiFreeUsed,
    limit: FREE_LIMIT,
    resetsAt: (user.freeMonthResetAt ?? new Date(Date.now() + 30 * 24 * 60 * 60 * 1_000)).toISOString(),
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

aiRouter.post(
  "/generate",
  authMiddleware,
  denylistMiddleware,
  aiUserHourlyLimitMiddleware,
  aiUserDailyLimitMiddleware,
  dailyBudgetMiddleware,
  perUserBudgetMiddleware,
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
        // Surface "unsupported_input_type" specifically for inputType errors so
        // the Flutter client can route to its "App error" modal vs the generic
        // "Invalid request" modal (feature-spec-flutter.md §4).
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
      if (body.inputType === "pdf" || body.inputType === "book") {
        const bytes = decodedBase64Bytes(body.fileBase64);
        if (bytes > MAX_DECODED_BYTES) {
          throw new HttpError(400, "file_too_large", "File exceeds the 5 MB limit.", {
            maxBytes: MAX_DECODED_BYTES,
            actualBytes: bytes,
          });
        }
      }

      // ── 4. Hash canonical body for idempotency cache ──────────────────────
      const requestHash = hashRequestBody(body);

      const aiRepo   = new PgAiGenerationRepository(pool);
      const userRepo = new PgUserRepository(pool);

      // ── 5. Resolve idempotency state ──────────────────────────────────────
      // Existing row first: cached success or cross-body conflict bypasses
      // every downstream check (premium gate, quota gate, Gemini work).
      const existing = await aiRepo.findByIdempotencyKey(req.user!.id, idempotencyKey);

      if (existing) {
        if (existing.requestHash !== requestHash) {
          throw new HttpError(409, "idempotency_conflict",
            "This Idempotency-Key was used with a different request body. Use a fresh key.",
            { originalRequestHash: existing.requestHash },
          );
        }
        if (existing.status === "success") {
          // Cached replay: same generationId + form, fresh quota snapshot.
          const quota = await getQuotaSnapshot(userRepo, req.user!.id);
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
          throw new HttpError(409, "idempotency_in_flight",
            "Your previous request is still being processed. Please retry in a moment.");
        }
        // existing.status is gemini_error or validation_error → take over.
      }

      // ── 6. Premium gate (free users blocked from non-text inputs) ─────────
      if (req.user!.tier === "free" && premiumOnlyInputType(body.inputType)) {
        throw new HttpError(403, "premium_required",
          "This input type requires a premium subscription.",
          { requiredEntitlement: "gfm_premium", requestedInputType: body.inputType },
        );
      }

      // ── 7. Quota gate ─────────────────────────────────────────────────────
      const quotaBefore = await getQuotaSnapshot(userRepo, req.user!.id);
      if (quotaBefore.used >= quotaBefore.limit) {
        throw new HttpError(429, "quota_exceeded",
          quotaBefore.tier === "free"
            ? `You've used all ${quotaBefore.limit} free generations this month.`
            : `You've used all ${quotaBefore.limit} generations this period.`,
          {
            tier:     quotaBefore.tier,
            used:     quotaBefore.used,
            limit:    quotaBefore.limit,
            resetsAt: quotaBefore.resetsAt,
          },
        );
      }

      // ── 8. Claim a row to own ──────────────────────────────────────────────
      let rowId: number;
      let generationId: string;

      if (existing) {
        // Take-over of a previously-failed row. claimFailedForRetry uses a
        // conditional UPDATE so concurrent retries can't both proceed.
        const claimed = await aiRepo.claimFailedForRetry(existing.id);
        if (!claimed) {
          throw new HttpError(409, "idempotency_in_flight",
            "Another retry took over this request. Please retry in a moment.");
        }
        rowId        = existing.id;
        generationId = existing.generationId;
      } else {
        // Fresh attempt: tryCreate handles the concurrent-INSERT race.
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
          // Lost the race. Re-fetch and route the existing row.
          const racingRow = await aiRepo.findByIdempotencyKey(req.user!.id, idempotencyKey);
          if (!racingRow) {
            // Extremely rare — UNIQUE conflict but no row. DB hiccup; surface as 503.
            throw new HttpError(503, "database_unavailable", "Please retry.");
          }
          if (racingRow.requestHash !== requestHash) {
            throw new HttpError(409, "idempotency_conflict",
              "This Idempotency-Key was used with a different request body. Use a fresh key.",
              { originalRequestHash: racingRow.requestHash },
            );
          }
          if (racingRow.status === "success") {
            const quota = await getQuotaSnapshot(userRepo, req.user!.id);
            res.json({
              generationId: racingRow.generationId,
              status:       "completed",
              form:         racingRow.outputJson,
              tokensUsed:   { input: racingRow.inputTokens ?? 0, output: racingRow.outputTokens ?? 0 },
              quota,
            });
            return;
          }
          // 'processing' or a freshly-failed row that beat us — tell the client to wait.
          throw new HttpError(409, "idempotency_in_flight",
            "Your previous request is still being processed. Please retry in a moment.");
        }
      }

      // ── 9. Run the Gemini pipeline ─────────────────────────────────────────
      const outcome = await runGeneration({
        user:    { id: req.user!.id, tier: req.user!.tier },
        body,
        rowId,
        generationId,
        aiRepo,
        userRepo,
        log: req.log,
      });

      // Stash on req for observability middleware (Task 16) to read in finish handler.
      req.geminiInputTokens  = outcome.inputTokens;
      req.geminiOutputTokens = outcome.outputTokens;

      // ── 10. Respond with success + fresh quota snapshot ────────────────────
      const quotaAfter = await getQuotaSnapshot(userRepo, req.user!.id);
      res.json({
        generationId: outcome.generationId,
        status:       "completed",
        form:         outcome.form,
        tokensUsed:   { input: outcome.inputTokens, output: outcome.outputTokens },
        quota:        quotaAfter,
      });
    } catch (err) {
      next(err);
    }
  },
);
