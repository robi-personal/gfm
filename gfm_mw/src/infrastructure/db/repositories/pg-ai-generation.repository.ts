import { AiGeneration, GenerationStatus, InputType } from "../../../domain/entities/ai-generation.entity";
import {
  AiGenerationRepository,
  CreateGenerationParams,
  UpdateGenerationFailureParams,
  UpdateGenerationSuccessParams,
} from "../../../domain/repositories/ai-generation.repository";
import { DbClient } from "../postgres";

// Gemini 2.0 Flash paid-tier pricing. See rate-limiting-abuse.md §8.3.
const INPUT_USD_PER_TOKEN  = 0.075  / 1_000_000;
const OUTPUT_USD_PER_TOKEN = 0.300  / 1_000_000;

function mapRow(row: Record<string, unknown>): AiGeneration {
  return {
    id:             row["id"] as number,
    generationId:   row["generation_id"] as string,
    userId:         row["user_id"] as number,
    idempotencyKey: row["idempotency_key"] as string,
    requestHash:    row["request_hash"] as string,
    inputType:      row["input_type"] as InputType,
    inputSize:      row["input_size"] as number | null,
    inputTokens:    row["input_tokens"] as number | null,
    outputTokens:   row["output_tokens"] as number | null,
    outputJson:     row["output_json"] ?? null,
    errorPayload:   row["error_payload"] ?? null,
    status:         row["status"] as GenerationStatus,
    createdAt:      row["created_at"] as Date,
    expiresAt:      row["expires_at"] as Date,
  };
}

export class PgAiGenerationRepository implements AiGenerationRepository {
  constructor(private readonly db: DbClient) {}

  async findByIdempotencyKey(
    userId: number,
    idempotencyKey: string,
  ): Promise<AiGeneration | null> {
    const { rows } = await this.db.query(
      `SELECT * FROM ai_generations
       WHERE user_id = $1 AND idempotency_key = $2`,
      [userId, idempotencyKey],
    );
    return rows[0] ? mapRow(rows[0]) : null;
  }

  async findByIdempotencyKeyForUpdate(
    userId: number,
    idempotencyKey: string,
  ): Promise<AiGeneration | null> {
    // FOR UPDATE serializes concurrent retries on the same key. See api-contract.md §5.5.
    const { rows } = await this.db.query(
      `SELECT * FROM ai_generations
       WHERE user_id = $1 AND idempotency_key = $2
       FOR UPDATE`,
      [userId, idempotencyKey],
    );
    return rows[0] ? mapRow(rows[0]) : null;
  }

  async create(params: CreateGenerationParams): Promise<AiGeneration> {
    const { rows } = await this.db.query(
      `INSERT INTO ai_generations
         (generation_id, user_id, idempotency_key, request_hash, input_type, input_size, status)
       VALUES ($1, $2, $3, $4, $5, $6, 'processing')
       RETURNING *`,
      [
        params.generationId,
        params.userId,
        params.idempotencyKey,
        params.requestHash,
        params.inputType,
        params.inputSize ?? null,
      ],
    );
    return mapRow(rows[0]);
  }

  async tryCreate(params: CreateGenerationParams): Promise<AiGeneration | null> {
    // ON CONFLICT DO NOTHING handles the concurrent-retry race without an
    // explicit lock. Caller re-fetches the existing row to choose the right
    // recovery path (cached success / in-flight / take-over failed).
    const { rows } = await this.db.query(
      `INSERT INTO ai_generations
         (generation_id, user_id, idempotency_key, request_hash, input_type, input_size, status)
       VALUES ($1, $2, $3, $4, $5, $6, 'processing')
       ON CONFLICT (user_id, idempotency_key) DO NOTHING
       RETURNING *`,
      [
        params.generationId,
        params.userId,
        params.idempotencyKey,
        params.requestHash,
        params.inputType,
        params.inputSize ?? null,
      ],
    );
    return rows[0] ? mapRow(rows[0]) : null;
  }

  async claimFailedForRetry(id: number): Promise<boolean> {
    // Conditional take-over. If two retries race, only one UPDATE matches
    // the failure status and returns rowCount=1; the loser sees rowCount=0
    // and the route returns 409 idempotency_in_flight.
    const result = await this.db.query(
      `UPDATE ai_generations
         SET status = 'processing', error_payload = NULL
       WHERE id = $1 AND status IN ('gemini_error', 'validation_error')`,
      [id],
    );
    return (result.rowCount ?? 0) > 0;
  }

  async updateStatus(id: number, status: GenerationStatus): Promise<void> {
    await this.db.query(
      "UPDATE ai_generations SET status = $2 WHERE id = $1",
      [id, status],
    );
  }

  async updateSuccess(
    id: number,
    params: UpdateGenerationSuccessParams,
  ): Promise<void> {
    await this.db.query(
      `UPDATE ai_generations SET
         status       = 'success',
         output_json  = $2,
         input_tokens  = $3,
         output_tokens = $4
       WHERE id = $1`,
      [id, params.outputJson, params.inputTokens, params.outputTokens],
    );
  }

  async updateFailure(
    id: number,
    params: UpdateGenerationFailureParams,
  ): Promise<void> {
    await this.db.query(
      `UPDATE ai_generations SET
         status        = $2,
         error_payload = $3,
         input_tokens  = $4,
         output_tokens = $5
       WHERE id = $1`,
      [
        id,
        params.status,
        params.errorPayload,
        params.inputTokens ?? null,
        params.outputTokens ?? null,
      ],
    );
  }

  async getTotalSpendUsd(userId: number, sinceMs: number): Promise<number> {
    const { rows } = await this.db.query(
      `SELECT
         COALESCE(SUM(input_tokens),  0) * $3
       + COALESCE(SUM(output_tokens), 0) * $4 AS spend_usd
       FROM ai_generations
       WHERE user_id    = $1
         AND created_at > to_timestamp($2 / 1000.0)`,
      [userId, sinceMs, INPUT_USD_PER_TOKEN, OUTPUT_USD_PER_TOKEN],
    );
    return parseFloat(rows[0]["spend_usd"] as string);
  }

  async getGlobalDailySpendUsd(): Promise<number> {
    const { rows } = await this.db.query(
      `SELECT
         COALESCE(SUM(input_tokens),  0) * $1
       + COALESCE(SUM(output_tokens), 0) * $2 AS spend_usd
       FROM ai_generations
       WHERE created_at >= date_trunc('day', NOW() AT TIME ZONE 'UTC')`,
      [INPUT_USD_PER_TOKEN, OUTPUT_USD_PER_TOKEN],
    );
    return parseFloat(rows[0]["spend_usd"] as string);
  }
}
