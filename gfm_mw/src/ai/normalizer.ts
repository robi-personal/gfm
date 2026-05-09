import type { SimpleFormType } from "./simple-schema";
import type { GeneratedForm } from "./form-schema";

// Maps simple model output to the full FormSchema shape,
// filling in type-specific defaults the model no longer needs to emit.

export function normalizeForm(simple: SimpleFormType): GeneratedForm {
  return {
    title:       simple.title,
    description: simple.description,
    questions:   simple.questions.map((q) => {
      const base = { title: q.title, required: q.required };

      switch (q.type) {
        case "short":
          return { ...base, type: "SHORT_ANSWER" as const };

        case "long":
          return { ...base, type: "PARAGRAPH" as const };

        case "choice":
          return { ...base, type: "MULTIPLE_CHOICE" as const, options: q.options ?? ["Option 1", "Option 2"] };

        case "multi":
          return { ...base, type: "CHECKBOXES" as const, options: q.options ?? ["Option 1", "Option 2"] };

        case "dropdown":
          return { ...base, type: "DROPDOWN" as const, options: q.options ?? ["Option 1", "Option 2"] };

        case "scale":
          return {
            ...base,
            type:          "LINEAR_SCALE" as const,
            scaleMin:      1,
            scaleMax:      5,
            scaleMinLabel: "Poor",
            scaleMaxLabel: "Excellent",
          };

        case "rating":
          return { ...base, type: "RATING" as const, ratingScale: 5 as const };

        case "date":
          return { ...base, type: "DATE" as const };

        case "time":
          return { ...base, type: "TIME" as const };
      }
    }),
  };
}
