import type { Content, Part } from "@google/generative-ai";
import { FORM_FEW_SHOTS, QUIZ_FEW_SHOTS } from "./few-shots";
import type { GenerateRequest } from "./request-schema";

interface UrlContent { url: string; text: string }

export interface BuildContentsArgs {
  body: GenerateRequest;
  fetchedUrls?: UrlContent[];
}

function questionCount(hint?: number): string {
  return hint ? String(hint) : "default";
}

function isQuizFlag(isQuiz: boolean): string {
  return isQuiz ? "true" : "false";
}

function textTurn(req: Extract<GenerateRequest, { inputType: "text" }>): Part {
  const text =
    `INPUT_TYPE: text\n` +
    `IS_QUIZ: ${isQuizFlag(req.isQuiz)}\n` +
    `QUESTION_COUNT: ${questionCount(req.questionCountHint)}\n\n` +
    req.prompt.trim();
  return { text };
}

function documentTurn(
  req: Extract<GenerateRequest, { inputType: "pdf" | "book" }>,
): Part[] {
  const scaffold =
    `INPUT_TYPE: ${req.inputType}\n` +
    `IS_QUIZ: ${isQuizFlag(req.isQuiz)}\n` +
    (req.fileName ? `FILE_NAME: ${req.fileName}\n` : "") +
    (req.description ? `USER_INTENT: ${req.description}\n` : "") +
    `QUESTION_COUNT: ${questionCount(req.questionCountHint)}\n\n` +
    `Read the attached document carefully. Generate questions based on the SPECIFIC content — do NOT generate generic questions.`;

  return [
    { text: scaffold },
    { inlineData: { mimeType: "application/pdf", data: req.fileBase64 } },
  ];
}

function youtubeTurn(req: Extract<GenerateRequest, { inputType: "youtube" }>): Part[] {
  const scaffold =
    `INPUT_TYPE: youtube\n` +
    `IS_QUIZ: ${isQuizFlag(req.isQuiz)}\n` +
    `URL: ${req.youtubeUrl}\n` +
    (req.description ? `USER_INTENT: ${req.description}\n` : "") +
    `QUESTION_COUNT: ${questionCount(req.questionCountHint)}\n\n` +
    `Build questions based on the attached YouTube video.`;
  return [
    { text: scaffold },
    { fileData: { mimeType: "video/*", fileUri: req.youtubeUrl } },
  ];
}

function urlsTurn(
  req: Extract<GenerateRequest, { inputType: "urls" }>,
  fetched: UrlContent[],
): Part {
  const blocks = fetched.map((f, i) =>
    `--- BEGIN FETCHED CONTENT (${i + 1} of ${fetched.length}) ---\n` +
    `URL: ${f.url}\n` +
    `TEXT: ${f.text}\n` +
    `--- END FETCHED CONTENT ---`,
  ).join("\n\n");

  const text =
    `INPUT_TYPE: urls\n` +
    `IS_QUIZ: ${isQuizFlag(req.isQuiz)}\n` +
    `URLS:\n${req.urls.map((u) => `  - ${u}`).join("\n")}\n` +
    (req.description ? `USER_INTENT: ${req.description}\n` : "") +
    `QUESTION_COUNT: ${questionCount(req.questionCountHint)}\n\n` +
    `Build questions based on the fetched content below.\n\n` +
    blocks;

  return { text };
}

export function buildContents(args: BuildContentsArgs): Content[] {
  const { body, fetchedUrls } = args;
  const fewShots = body.isQuiz ? QUIZ_FEW_SHOTS : FORM_FEW_SHOTS;

  let userParts: Part[];
  switch (body.inputType) {
    case "text":    userParts = [textTurn(body)]; break;
    case "pdf":     userParts = documentTurn(body); break;
    case "book":    userParts = documentTurn(body); break;
    case "youtube": userParts = youtubeTurn(body); break;
    case "urls":    userParts = [urlsTurn(body, fetchedUrls ?? [])]; break;
  }

  return [
    ...fewShots,
    { role: "user", parts: userParts },
  ];
}
