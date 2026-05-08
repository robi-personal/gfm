export type GenerationStatus = "processing" | "success" | "gemini_error" | "validation_error";

export type InputType = "text" | "pdf" | "youtube" | "urls" | "book";

export interface AiGeneration {
  id: number;
  generationId: string;
  userId: number;
  idempotencyKey: string;
  requestHash: string;
  inputType: InputType;
  inputSize: number | null;
  inputTokens: number | null;
  outputTokens: number | null;
  outputJson: unknown | null;
  errorPayload: unknown | null;
  status: GenerationStatus;
  createdAt: Date;
  expiresAt: Date;
}
