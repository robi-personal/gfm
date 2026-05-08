import { AiGeneration, GenerationStatus, InputType } from "../entities/ai-generation.entity";

export interface CreateGenerationParams {
  generationId: string;
  userId: number;
  idempotencyKey: string;
  requestHash: string;
  inputType: InputType;
  inputSize?: number;
}

export interface UpdateGenerationSuccessParams {
  outputJson: unknown;
  inputTokens: number;
  outputTokens: number;
}

export interface UpdateGenerationFailureParams {
  status: "gemini_error" | "validation_error";
  errorPayload: unknown;
  inputTokens?: number;
  outputTokens?: number;
}

export interface AiGenerationRepository {
  findByIdempotencyKey(userId: number, idempotencyKey: string): Promise<AiGeneration | null>;
  findByIdempotencyKeyForUpdate(userId: number, idempotencyKey: string): Promise<AiGeneration | null>;
  create(params: CreateGenerationParams): Promise<AiGeneration>;
  updateStatus(id: number, status: GenerationStatus): Promise<void>;
  updateSuccess(id: number, params: UpdateGenerationSuccessParams): Promise<void>;
  updateFailure(id: number, params: UpdateGenerationFailureParams): Promise<void>;
  getTotalSpendUsd(userId: number, sinceMs: number): Promise<number>;
  getGlobalDailySpendUsd(): Promise<number>;
}
