import { z } from "zod";
import { SchemaType } from "@google/generative-ai";

// Simple question types the model emits — easier for weaker models to follow.
export const SimpleQuestionType = z.enum([
  "short",    // → SHORT_ANSWER
  "long",     // → PARAGRAPH
  "choice",   // → MULTIPLE_CHOICE  (needs options)
  "multi",    // → CHECKBOXES       (needs options)
  "dropdown", // → DROPDOWN         (needs options)
  "scale",    // → LINEAR_SCALE     (backend fills defaults)
  "rating",   // → RATING           (backend fills ratingScale: 5)
  "date",     // → DATE
  "time",     // → TIME
]);

const GRADEABLE_TYPES = new Set<z.infer<typeof SimpleQuestionType>>([
  "choice", "multi", "dropdown", "short",
]);

export const SimpleQuestion = z.object({
  title:    z.string().trim().min(1).max(1000),
  type:     SimpleQuestionType,
  options:  z.array(z.string().trim().min(1).max(200)).min(2).max(20).optional(),
  required: z.boolean().default(false),

  // Quiz-only fields. Cross-field validation lives in SimpleForm.superRefine
  // because gating depends on form-level isQuiz.
  correctAnswers: z.array(z.string().trim().min(1).max(200)).min(1).max(20).optional(),
  pointValue:     z.number().int().min(1).max(10).optional(),
  whenRight:      z.string().trim().min(1).max(500).optional(),
  whenWrong:      z.string().trim().min(1).max(500).optional(),
});

export const SimpleForm = z
  .object({
    title:       z.string().trim().min(1).max(300),
    description: z.string().trim().max(2000).optional(),
    isQuiz:      z.boolean().default(false),
    questions:   z.array(SimpleQuestion).min(1).max(50),
  })
  .superRefine((form, ctx) => {
    form.questions.forEach((q, i) => {
      const path = (k: string) => ["questions", i, k] as const;

      if (form.isQuiz) {
        if (!GRADEABLE_TYPES.has(q.type)) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            message: `Quiz questions cannot use "${q.type}" — only choice, multi, dropdown, short`,
            path: [...path("type")],
          });
        }
        if (!q.correctAnswers || q.correctAnswers.length === 0) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            message: "Quiz questions require correctAnswers",
            path: [...path("correctAnswers")],
          });
        }
        if (q.type !== "multi" && q.correctAnswers && q.correctAnswers.length !== 1) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            message: "Only multi questions can have multiple correct answers",
            path: [...path("correctAnswers")],
          });
        }
        if (q.options && q.correctAnswers && q.type !== "short") {
          const opts = new Set(q.options);
          const bad = q.correctAnswers.filter((a) => !opts.has(a));
          if (bad.length > 0) {
            ctx.addIssue({
              code: z.ZodIssueCode.custom,
              message: `correctAnswers must match an option exactly: ${bad.join(", ")}`,
              path: [...path("correctAnswers")],
            });
          }
        }
      } else {
        if (q.correctAnswers || q.pointValue !== undefined || q.whenRight || q.whenWrong) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            message: "Form questions cannot include quiz fields (correctAnswers, pointValue, whenRight, whenWrong)",
            path: [...path("correctAnswers")],
          });
        }
      }
    });
  });

export type SimpleFormType = z.infer<typeof SimpleForm>;

// Gemini structured-output schema. Quiz fields are listed as optional here
// (a single shape covers form + quiz). The strict gate is SimpleForm.superRefine
// — Gemini's responseSchema is a soft hint; Zod is the gate.
export const SIMPLE_RESPONSE_SCHEMA = {
  type: SchemaType.OBJECT,
  properties: {
    title:       { type: SchemaType.STRING },
    description: { type: SchemaType.STRING },
    isQuiz:      { type: SchemaType.BOOLEAN },
    questions: {
      type: SchemaType.ARRAY,
      items: {
        type: SchemaType.OBJECT,
        properties: {
          title:    { type: SchemaType.STRING },
          type: {
            type: SchemaType.STRING,
            enum: ["short", "long", "choice", "multi", "dropdown", "scale", "rating", "date", "time"],
          },
          options:  { type: SchemaType.ARRAY, items: { type: SchemaType.STRING } },
          required: { type: SchemaType.BOOLEAN },

          correctAnswers: { type: SchemaType.ARRAY, items: { type: SchemaType.STRING } },
          pointValue:     { type: SchemaType.INTEGER },
          whenRight:      { type: SchemaType.STRING },
          whenWrong:      { type: SchemaType.STRING },
        },
        required: ["title", "type"],
      },
    },
  },
  required: ["title", "isQuiz", "questions"],
};
