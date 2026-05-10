import type { SimpleFormType } from "./simple-schema";
import type { GeneratedForm } from "./form-schema";

// Maps simple model output to the full FormSchema shape, filling in
// type-specific defaults the model no longer needs to emit. Quiz fields
// (correctAnswers / pointValue / whenRight / whenWrong) are folded into a
// `grading` object on gradeable question types when the form is a quiz.

type SimpleQuestion = SimpleFormType["questions"][number];

function gradingFor(q: SimpleQuestion, isQuiz: boolean) {
  if (!isQuiz || !q.correctAnswers || q.correctAnswers.length === 0) return undefined;
  return {
    correctAnswers: q.correctAnswers,
    pointValue:     q.pointValue ?? 1,
    ...(q.whenRight ? { whenRight: q.whenRight } : {}),
    ...(q.whenWrong ? { whenWrong: q.whenWrong } : {}),
  };
}

export function normalizeForm(simple: SimpleFormType): GeneratedForm {
  const isQuiz = simple.isQuiz;

  return {
    title:       simple.title,
    description: simple.description,
    isQuiz,
    questions:   simple.questions.map((q) => {
      const base = { title: q.title, required: q.required };
      const grading = gradingFor(q, isQuiz);

      switch (q.type) {
        case "short":
          return { ...base, type: "SHORT_ANSWER" as const, ...(grading ? { grading } : {}) };

        case "long":
          return { ...base, type: "PARAGRAPH" as const };

        case "choice":
          return {
            ...base,
            type: "MULTIPLE_CHOICE" as const,
            options: q.options ?? ["Option 1", "Option 2"],
            ...(grading ? { grading } : {}),
          };

        case "multi":
          return {
            ...base,
            type: "CHECKBOXES" as const,
            options: q.options ?? ["Option 1", "Option 2"],
            ...(grading ? { grading } : {}),
          };

        case "dropdown":
          return {
            ...base,
            type: "DROPDOWN" as const,
            options: q.options ?? ["Option 1", "Option 2"],
            ...(grading ? { grading } : {}),
          };

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
