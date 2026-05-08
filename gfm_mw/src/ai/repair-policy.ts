import { z } from "zod";

const VALID_TYPES = new Set([
  "SHORT_ANSWER", "PARAGRAPH", "MULTIPLE_CHOICE", "CHECKBOXES",
  "DROPDOWN", "LINEAR_SCALE", "DATE", "TIME", "RATING",
]);

function isObject(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

// Exact fallback-form check per ai-prompt-spec §9.1.
export function isFallbackForm(candidate: unknown): boolean {
  if (!isObject(candidate)) return false;
  if (candidate["title"] !== "Unable to generate form") return false;

  const questions = candidate["questions"];
  if (!Array.isArray(questions) || questions.length !== 1) return false;

  const q = questions[0];
  if (!isObject(q)) return false;
  if (q["type"] !== "SHORT_ANSWER") return false;
  if (typeof q["title"] !== "string") return false;
  if (!q["title"].toLowerCase().includes("did you mean")) return false;

  return true;
}

// Fatal-error detector per ai-prompt-spec §6.3. Returns true when the error is
// structural and unlikely to be recovered by a Gemini repair turn.
export function isFatal(zodError: z.ZodError, candidate: unknown): boolean {
  // null means parseAndAutoRepair produced no parseable object.
  if (candidate === null || candidate === undefined) return true;

  if (!isObject(candidate)) return true;

  const questions = candidate["questions"];

  // Top-level shape wrong.
  if (!Array.isArray(questions)) return true;

  // Hard product caps.
  if (questions.length > 50) return true;
  if (questions.length === 0) return true;

  // Any question uses an unsupported type.
  for (const q of questions) {
    if (isObject(q) && typeof q["type"] === "string" && !VALID_TYPES.has(q["type"])) {
      return true;
    }
  }

  // Intentional Gemini refusal — surface as validation_error, don't repair.
  if (isFallbackForm(candidate)) return true;

  // > 25% of questions have at least one "Required" (missing field) Zod issue.
  const missingFieldIndices = new Set<number>();
  for (const issue of zodError.issues) {
    if (
      issue.path.length >= 2 &&
      issue.path[0] === "questions" &&
      typeof issue.path[1] === "number" &&
      issue.message === "Required"
    ) {
      missingFieldIndices.add(issue.path[1]);
    }
  }
  if (questions.length > 0 && missingFieldIndices.size / questions.length > 0.25) {
    return true;
  }

  return false;
}

// Renders Zod issues into the bullet list sent as the REPAIR turn (§5 pipeline).
export function formatZodErrors(zodError: z.ZodError): string {
  return zodError.issues
    .map((issue) => {
      let path = issue.path.map(String).join(".");
      if (path.length > 80) path = path.slice(0, 77) + "...";
      const location = path || "(root)";
      return `- ${location}: ${issue.message}`;
    })
    .join("\n");
}
