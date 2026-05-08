import type { Content } from "@google/generative-ai";

// Two text-mode few-shots per ai-prompt-spec.md §7.1. They demonstrate the
// JSON output contract — which is the main thing in-context examples buy us.
// File-mode inputs (pdf/youtube/urls/book) reuse these because few-shotting
// real PDF bytes / video URIs is expensive and the JSON shape lesson is the
// same.

const BAKERY_INPUT = `INPUT_TYPE: text
QUESTION_COUNT: default

Customer feedback survey for a small bakery. Ask about visit frequency,
favorite items, satisfaction, and any suggestions.`;

const BAKERY_OUTPUT = JSON.stringify({
  title: "Bakery Customer Feedback",
  description: "Help us improve! This survey takes about 2 minutes.",
  questions: [
    { title: "How often do you visit our bakery?", type: "MULTIPLE_CHOICE", required: true,
      options: ["First time", "Once a month", "Weekly", "Several times a week"] },
    { title: "Which items have you tried? (Select all that apply)", type: "CHECKBOXES", required: false,
      options: ["Sourdough", "Croissants", "Cakes", "Cookies", "Coffee"] },
    { title: "How would you rate the quality of your last order?", type: "RATING", required: true, ratingScale: 5 },
    { title: "How satisfied were you overall?", type: "LINEAR_SCALE", required: true,
      scaleMin: 1, scaleMax: 5, scaleMinLabel: "Very dissatisfied", scaleMaxLabel: "Very satisfied" },
    { title: "What was the best part of your visit?", type: "SHORT_ANSWER", required: false },
    { title: "What could we improve?", type: "PARAGRAPH", required: false },
    { title: "Would you recommend us to a friend?", type: "MULTIPLE_CHOICE", required: true,
      options: ["Definitely", "Probably", "Not sure", "Probably not", "Definitely not"] },
    { title: "May we contact you about your feedback?", type: "MULTIPLE_CHOICE", required: true,
      options: ["Yes", "No"] },
    { title: "If yes, what is your email?",
      description: "Optional — only if you want a reply.",
      type: "SHORT_ANSWER", required: false },
    { title: "Date of your most recent visit", type: "DATE", required: false },
  ],
});

const QUIZ_INPUT = `INPUT_TYPE: text
QUESTION_COUNT: 8

Quick quiz for 5th graders on US state capitals. Mix of multiple-choice
and short-answer.`;

const QUIZ_OUTPUT = JSON.stringify({
  title: "US State Capitals Quiz",
  description: "Test your knowledge of US state capitals. 8 questions.",
  questions: [
    { title: "What is the capital of California?", type: "MULTIPLE_CHOICE", required: true,
      options: ["Los Angeles", "San Francisco", "Sacramento", "San Diego"] },
    { title: "What is the capital of Texas?", type: "MULTIPLE_CHOICE", required: true,
      options: ["Houston", "Dallas", "Austin", "San Antonio"] },
    { title: "What is the capital of New York State?", type: "MULTIPLE_CHOICE", required: true,
      options: ["New York City", "Buffalo", "Rochester", "Albany"] },
    { title: "Type the capital of Florida.", type: "SHORT_ANSWER", required: true },
    { title: "Type the capital of Illinois.", type: "SHORT_ANSWER", required: true },
    { title: "What is the capital of Washington State?", type: "MULTIPLE_CHOICE", required: true,
      options: ["Seattle", "Olympia", "Spokane", "Tacoma"] },
    { title: "Type the capital of Georgia.", type: "SHORT_ANSWER", required: true },
    { title: "Type the capital of Massachusetts.", type: "SHORT_ANSWER", required: true },
  ],
});

export const FEW_SHOTS: Content[] = [
  { role: "user",  parts: [{ text: BAKERY_INPUT  }] },
  { role: "model", parts: [{ text: BAKERY_OUTPUT }] },
  { role: "user",  parts: [{ text: QUIZ_INPUT   }] },
  { role: "model", parts: [{ text: QUIZ_OUTPUT  }] },
];
