import { z } from "zod";

// Per api-contract.md §3 GenerateRequest oneOf with discriminator.
// Per-inputType bodies validated in /ai/generate before any external work.

const QuestionCountHint = z.number().int().min(3).max(50);

// 5MB decoded cap → ~6.7M base64 chars (4/3 ratio plus padding).
const MAX_BASE64_CHARS = Math.ceil((5 * 1024 * 1024) * 4 / 3) + 4;

const Base64Pdf = z
  .string()
  .min(1)
  .max(MAX_BASE64_CHARS)
  // Strict base64 — strips data: URIs is the client's responsibility.
  .regex(/^[A-Za-z0-9+/]+={0,2}$/, "Must be standard base64");

const YouTubeUrl = z
  .string()
  .url()
  .regex(
    /^https?:\/\/(www\.)?(youtube\.com\/watch\?v=|youtu\.be\/)[A-Za-z0-9_-]{11}/,
    "Must be a valid YouTube URL",
  );

const HttpUrl = z.string().url().regex(/^https?:\/\//, "Must be http or https");

export const TextRequest = z
  .object({
    inputType: z.literal("text"),
    prompt: z.string().min(1).max(4_000),
    questionCountHint: QuestionCountHint.optional(),
  })
  .strict();

export const PdfRequest = z
  .object({
    inputType: z.literal("pdf"),
    fileBase64: Base64Pdf,
    fileName: z.string().max(255).optional(),
    description: z.string().max(2000).optional(),
    questionCountHint: QuestionCountHint.optional(),
  })
  .strict();

export const YouTubeRequest = z
  .object({
    inputType: z.literal("youtube"),
    youtubeUrl: YouTubeUrl,
    description: z.string().max(2000).optional(),
    questionCountHint: QuestionCountHint.optional(),
  })
  .strict();

export const UrlsRequest = z
  .object({
    inputType: z.literal("urls"),
    urls: z.array(HttpUrl).min(1).max(5),
    description: z.string().max(2000).optional(),
    questionCountHint: QuestionCountHint.optional(),
  })
  .strict();

export const BookRequest = z
  .object({
    inputType: z.literal("book"),
    fileBase64: Base64Pdf,
    description: z.string().max(2000).optional(),
    questionCountHint: QuestionCountHint.optional(),
  })
  .strict();

export const GenerateRequest = z.discriminatedUnion("inputType", [
  TextRequest,
  PdfRequest,
  YouTubeRequest,
  UrlsRequest,
  BookRequest,
]);

export type GenerateRequest = z.infer<typeof GenerateRequest>;

// Decoded byte size of a (validated) base64 string. Validation has already
// confirmed the string only contains base64 chars + padding.
export function decodedBase64Bytes(b64: string): number {
  const padding = b64.endsWith("==") ? 2 : b64.endsWith("=") ? 1 : 0;
  return Math.floor(b64.length * 3 / 4) - padding;
}

export const MAX_DECODED_BYTES = 5 * 1024 * 1024;
