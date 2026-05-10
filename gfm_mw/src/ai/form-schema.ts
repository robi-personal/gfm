import { z } from "zod";

export const QuestionType = z.enum([
  "SHORT_ANSWER",
  "PARAGRAPH",
  "MULTIPLE_CHOICE",
  "CHECKBOXES",
  "DROPDOWN",
  "LINEAR_SCALE",
  "DATE",
  "TIME",
  "RATING",
]);

const OptionString = z.string().trim().min(1).max(200);

// Grading nested object — matches Google Forms API shape. Only attached to
// gradeable question types (MULTIPLE_CHOICE / CHECKBOXES / DROPDOWN / SHORT_ANSWER)
// when the form is a quiz. The downstream Forms API mapper translates
// whenRight/whenWrong → generalFeedback for CHECKBOXES (per-answer feedback
// is not supported there).
const Grading = z
  .object({
    correctAnswers: z.array(OptionString).min(1).max(20),
    pointValue:     z.number().int().min(1).max(10),
    whenRight:      z.string().trim().min(1).max(500).optional(),
    whenWrong:      z.string().trim().min(1).max(500).optional(),
  })
  .strict();

const BaseQuestion = z.object({
  title:       z.string().trim().min(1).max(1000),
  description: z.string().trim().max(2000).optional(),
  required:    z.boolean().default(false),
});

const ChoiceQuestion = BaseQuestion.extend({
  type:    z.enum(["MULTIPLE_CHOICE", "CHECKBOXES", "DROPDOWN"]),
  options: z
    .array(OptionString)
    .min(2)
    .max(20)
    .refine((arr) => new Set(arr).size === arr.length, {
      message: "Duplicate option values",
    }),
  grading: Grading.optional(),
}).strict();

// Note: the scaleMin < scaleMax cross-field check cannot live on ScaleQuestion
// directly because .refine() wraps it in ZodEffects, which discriminatedUnion
// does not accept. The check is applied in FormSchema.superRefine() below.
const ScaleQuestion = BaseQuestion.extend({
  type:          z.literal("LINEAR_SCALE"),
  scaleMin:      z.number().int().min(0).max(1),
  scaleMax:      z.number().int().min(2).max(10),
  scaleMinLabel: z.string().trim().min(1).max(50),
  scaleMaxLabel: z.string().trim().min(1).max(50),
}).strict();

const RatingQuestion = BaseQuestion.extend({
  type:        z.literal("RATING"),
  ratingScale: z.union([z.literal(3), z.literal(5), z.literal(10)]),
}).strict();

const ShortAnswerQuestion = BaseQuestion.extend({
  type:    z.literal("SHORT_ANSWER"),
  grading: Grading.optional(),
}).strict();

const PlainQuestion = BaseQuestion.extend({
  type: z.enum(["PARAGRAPH", "DATE", "TIME"]),
}).strict();

// discriminatedUnion requires a ZodLiteral per branch; split ChoiceQuestion
// into three identical-shape branches and PlainQuestion into three.
export const Question = z.discriminatedUnion("type", [
  ChoiceQuestion.extend({ type: z.literal("MULTIPLE_CHOICE") }),
  ChoiceQuestion.extend({ type: z.literal("CHECKBOXES") }),
  ChoiceQuestion.extend({ type: z.literal("DROPDOWN") }),
  ScaleQuestion,
  RatingQuestion,
  ShortAnswerQuestion,
  PlainQuestion.extend({ type: z.literal("PARAGRAPH") }),
  PlainQuestion.extend({ type: z.literal("DATE") }),
  PlainQuestion.extend({ type: z.literal("TIME") }),
]);

const GRADEABLE = new Set(["MULTIPLE_CHOICE", "CHECKBOXES", "DROPDOWN", "SHORT_ANSWER"]);

export const FormSchema = z
  .object({
    title:       z.string().trim().min(1).max(300),
    description: z.string().trim().max(2000).optional(),
    isQuiz:      z.boolean().default(false),
    questions:   z.array(Question).min(1).max(50),
  })
  .strict()
  .superRefine((form, ctx) => {
    form.questions.forEach((q, i) => {
      if (q.type === "LINEAR_SCALE" && q.scaleMin >= q.scaleMax) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: "scaleMin must be < scaleMax",
          path: ["questions", i, "scaleMin"],
        });
      }

      if (form.isQuiz) {
        if (!GRADEABLE.has(q.type)) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            message: `Quiz questions cannot use "${q.type}" — only MULTIPLE_CHOICE, CHECKBOXES, DROPDOWN, SHORT_ANSWER`,
            path: ["questions", i, "type"],
          });
        }
        // The grading field only exists on gradeable branches; when
        // GRADEABLE.has(q.type) is true the discriminated union has narrowed
        // q to a branch that has it.
        if (GRADEABLE.has(q.type) && !("grading" in q && q.grading)) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            message: "Quiz questions require grading",
            path: ["questions", i, "grading"],
          });
        }
        if ("grading" in q && q.grading && "options" in q && q.options) {
          const opts = new Set(q.options);
          const bad = q.grading.correctAnswers.filter((a) => !opts.has(a));
          if (bad.length > 0) {
            ctx.addIssue({
              code: z.ZodIssueCode.custom,
              message: `correctAnswers must match an option exactly: ${bad.join(", ")}`,
              path: ["questions", i, "grading", "correctAnswers"],
            });
          }
        }
        if ("grading" in q && q.grading && q.type !== "CHECKBOXES" && q.grading.correctAnswers.length !== 1) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            message: "Only CHECKBOXES questions can have multiple correct answers",
            path: ["questions", i, "grading", "correctAnswers"],
          });
        }
      } else {
        if ("grading" in q && q.grading) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            message: "Form questions cannot include grading",
            path: ["questions", i, "grading"],
          });
        }
      }
    });
  });

export type GeneratedForm = z.infer<typeof FormSchema>;
