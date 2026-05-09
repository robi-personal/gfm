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

export const SimpleQuestion = z.object({
  title:    z.string().trim().min(1).max(1000),
  type:     SimpleQuestionType,
  options:  z.array(z.string().trim().min(1).max(200)).min(2).max(20).optional(),
  required: z.boolean().default(false),
});

export const SimpleForm = z.object({
  title:       z.string().trim().min(1).max(300),
  description: z.string().trim().max(2000).optional(),
  questions:   z.array(SimpleQuestion).min(1).max(50),
});

export type SimpleFormType = z.infer<typeof SimpleForm>;

// Gemini structured-output schema matching SimpleForm.
export const SIMPLE_RESPONSE_SCHEMA = {
  type: SchemaType.OBJECT,
  properties: {
    title:       { type: SchemaType.STRING },
    description: { type: SchemaType.STRING },
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
        },
        required: ["title", "type"],
      },
    },
  },
  required: ["title", "questions"],
};
