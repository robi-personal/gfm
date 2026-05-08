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

const PlainQuestion = BaseQuestion.extend({
  type: z.enum(["SHORT_ANSWER", "PARAGRAPH", "DATE", "TIME"]),
}).strict();

// discriminatedUnion requires a ZodLiteral per branch; split ChoiceQuestion
// into three identical-shape branches and PlainQuestion into four.
export const Question = z.discriminatedUnion("type", [
  ChoiceQuestion.extend({ type: z.literal("MULTIPLE_CHOICE") }),
  ChoiceQuestion.extend({ type: z.literal("CHECKBOXES") }),
  ChoiceQuestion.extend({ type: z.literal("DROPDOWN") }),
  ScaleQuestion,
  RatingQuestion,
  PlainQuestion.extend({ type: z.literal("SHORT_ANSWER") }),
  PlainQuestion.extend({ type: z.literal("PARAGRAPH") }),
  PlainQuestion.extend({ type: z.literal("DATE") }),
  PlainQuestion.extend({ type: z.literal("TIME") }),
]);

export const FormSchema = z
  .object({
    title:       z.string().trim().min(1).max(300),
    description: z.string().trim().max(2000).optional(),
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
    });
  });

export type GeneratedForm = z.infer<typeof FormSchema>;
