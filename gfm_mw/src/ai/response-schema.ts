import { SchemaType } from "@google/generative-ai";

// Permissive Gemini structured-output schema. Only required fields are required;
// type-specific fields (options, scaleMin/Max/Labels, ratingScale) are listed as
// optional so a single shape covers all 9 question types. The strict gate is
// the Zod schema in form-schema.ts (per ai-prompt-spec §4 — "Gemini responseSchema
// is a soft hint; Zod is the gate").

export const GEMINI_RESPONSE_SCHEMA = {
  type: SchemaType.OBJECT,
  properties: {
    title:       { type: SchemaType.STRING },
    description: { type: SchemaType.STRING },
    questions: {
      type: SchemaType.ARRAY,
      items: {
        type: SchemaType.OBJECT,
        properties: {
          title:       { type: SchemaType.STRING },
          description: { type: SchemaType.STRING },
          required:    { type: SchemaType.BOOLEAN },
          type: {
            type: SchemaType.STRING,
            enum: [
              "SHORT_ANSWER", "PARAGRAPH",
              "MULTIPLE_CHOICE", "CHECKBOXES", "DROPDOWN",
              "LINEAR_SCALE", "DATE", "TIME", "RATING",
            ],
          },
          options: {
            type: SchemaType.ARRAY,
            items: { type: SchemaType.STRING },
          },
          scaleMin:      { type: SchemaType.INTEGER },
          scaleMax:      { type: SchemaType.INTEGER },
          scaleMinLabel: { type: SchemaType.STRING  },
          scaleMaxLabel: { type: SchemaType.STRING  },
          ratingScale:   { type: SchemaType.INTEGER },
        },
        required: ["title", "type"],
      },
    },
  },
  required: ["title", "questions"],
};
