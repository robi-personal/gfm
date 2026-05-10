import type { Content } from "@google/generative-ai";

// Two text-mode few-shots per ai-prompt-spec.md §7.1. They demonstrate the
// JSON output contract — which is the main thing in-context examples buy us.
// File-mode inputs (pdf/youtube/urls/book) reuse these because few-shotting
// real PDF bytes / video URIs is expensive and the JSON shape lesson is the
// same. Both shots carry isQuiz so the model sees the field set both ways.

const BAKERY_INPUT = `INPUT_TYPE: text
QUESTION_COUNT: default

Customer feedback survey for a small bakery. Ask about visit frequency,
favorite items, satisfaction, and any suggestions.`;

const BAKERY_OUTPUT = JSON.stringify({
  title: "Bakery Customer Feedback",
  description: "Help us improve! This survey takes about 2 minutes.",
  isQuiz: false,
  questions: [
    { title: "How often do you visit our bakery?", type: "choice", required: true,
      options: ["First time", "Once a month", "Weekly", "Several times a week"] },
    { title: "Which items have you tried? (Select all that apply)", type: "multi", required: false,
      options: ["Sourdough", "Croissants", "Cakes", "Cookies", "Coffee"] },
    { title: "How would you rate the quality of your last order?", type: "rating", required: true },
    { title: "How satisfied were you overall?", type: "scale", required: true },
    { title: "What was the best part of your visit?", type: "short", required: false },
    { title: "What could we improve?", type: "long", required: false },
    { title: "Would you recommend us to a friend?", type: "choice", required: true,
      options: ["Definitely", "Probably", "Not sure", "Probably not", "Definitely not"] },
    { title: "May we contact you about your feedback?", type: "choice", required: true,
      options: ["Yes", "No"] },
    { title: "If yes, what is your email?", type: "short", required: false },
    { title: "Date of your most recent visit", type: "date", required: false },
  ],
});

const QUIZ_INPUT = `INPUT_TYPE: text
QUESTION_COUNT: 8

Quick quiz for 5th graders on US state capitals. Mix of multiple-choice
and short-answer.`;

const QUIZ_OUTPUT = JSON.stringify({
  title: "US State Capitals Quiz",
  description: "8 questions on US state capitals, mixing multiple-choice and short-answer.",
  isQuiz: true,
  questions: [
    {
      title: "What is the capital of California?",
      type: "choice", required: true,
      options: ["Los Angeles", "San Francisco", "Sacramento", "San Diego"],
      correctAnswers: ["Sacramento"], pointValue: 1,
      whenRight: "Correct! Sacramento has been the capital since 1854.",
      whenWrong: "The capital of California is Sacramento.",
    },
    {
      title: "What is the capital of Texas?",
      type: "choice", required: true,
      options: ["Houston", "Dallas", "Austin", "San Antonio"],
      correctAnswers: ["Austin"], pointValue: 1,
      whenRight: "Correct!",
      whenWrong: "The capital of Texas is Austin.",
    },
    {
      title: "Type the capital of Florida.",
      type: "short", required: true,
      correctAnswers: ["Tallahassee"], pointValue: 2,
      whenRight: "Correct!",
      whenWrong: "The capital of Florida is Tallahassee.",
    },
    {
      title: "Type the capital of Illinois.",
      type: "short", required: true,
      correctAnswers: ["Springfield"], pointValue: 2,
      whenRight: "Correct!",
      whenWrong: "The capital of Illinois is Springfield.",
    },
    {
      title: "What is the capital of Washington State?",
      type: "choice", required: true,
      options: ["Seattle", "Olympia", "Spokane", "Tacoma"],
      correctAnswers: ["Olympia"], pointValue: 1,
      whenRight: "Correct! Olympia, not Seattle.",
      whenWrong: "The capital of Washington State is Olympia, not Seattle.",
    },
    {
      title: "Type the capital of Georgia.",
      type: "short", required: true,
      correctAnswers: ["Atlanta"], pointValue: 1,
      whenRight: "Correct!",
      whenWrong: "The capital of Georgia is Atlanta.",
    },
    {
      title: "Type the capital of Massachusetts.",
      type: "short", required: true,
      correctAnswers: ["Boston"], pointValue: 1,
      whenRight: "Correct!",
      whenWrong: "The capital of Massachusetts is Boston.",
    },
    {
      title: "What is the capital of New York State?",
      type: "choice", required: true,
      options: ["New York City", "Buffalo", "Rochester", "Albany"],
      correctAnswers: ["Albany"], pointValue: 2,
      whenRight: "Correct! Many people guess NYC.",
      whenWrong: "The capital of New York State is Albany — not NYC.",
    },
  ],
});

export const FEW_SHOTS: Content[] = [
  { role: "user",  parts: [{ text: BAKERY_INPUT  }] },
  { role: "model", parts: [{ text: BAKERY_OUTPUT }] },
  { role: "user",  parts: [{ text: QUIZ_INPUT   }] },
  { role: "model", parts: [{ text: QUIZ_OUTPUT  }] },
];
