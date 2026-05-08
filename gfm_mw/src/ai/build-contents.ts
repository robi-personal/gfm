import type { Content, Part } from "@google/generative-ai";
import { FEW_SHOTS } from "./few-shots";
import type { GenerateRequest } from "./request-schema";

// Builds the `contents[]` payload for a Gemini call. System prompt and
// few-shots are kept separate (system instruction goes in model config; few-shots
// prepend the user turn) per ai-prompt-spec §3.2.

interface UrlContent { url: string; text: string }

export interface BuildContentsArgs {
  body: GenerateRequest;
  fetchedUrls?: UrlContent[];   // populated for inputType=urls (Task 11 fetcher)
}

function questionCount(hint?: number): string {
  return hint ? String(hint) : "default";
}

function textTurn(req: Extract<GenerateRequest, { inputType: "text" }>): Part {
  const text =
    `INPUT_TYPE: text\n` +
    `QUESTION_COUNT: ${questionCount(req.questionCountHint)}\n\n` +
    req.prompt.trim();
  return { text };
}

function pdfTurn(req: Extract<GenerateRequest, { inputType: "pdf" }>): Part[] {
  const scaffold =
    `INPUT_TYPE: pdf\n` +
    (req.fileName ? `FILE_NAME: ${req.fileName}\n` : "") +
    `QUESTION_COUNT: ${questionCount(req.questionCountHint)}\n\n` +
    `Build a form based on the attached PDF.`;
  return [
    { text: scaffold },
    { inlineData: { mimeType: "application/pdf", data: req.fileBase64 } },
  ];
}

function bookTurn(req: Extract<GenerateRequest, { inputType: "book" }>): Part[] {
  const scaffold =
    `INPUT_TYPE: book\n` +
    (req.chapterTitle ? `CHAPTER_TITLE: ${req.chapterTitle}\n` : "") +
    `QUESTION_COUNT: ${questionCount(req.questionCountHint)}\n\n` +
    `Build a comprehension form based on the attached chapter.`;
  return [
    { text: scaffold },
    { inlineData: { mimeType: "application/pdf", data: req.fileBase64 } },
  ];
}

function youtubeTurn(req: Extract<GenerateRequest, { inputType: "youtube" }>): Part[] {
  const scaffold =
    `INPUT_TYPE: youtube\n` +
    `URL: ${req.youtubeUrl}\n` +
    `QUESTION_COUNT: ${questionCount(req.questionCountHint)}\n\n` +
    `Build a form based on the attached YouTube video.`;
  // Per ai-prompt-spec §7.3, YouTube is passed as a fileData part with the URL
  // as the fileUri. mimeType is video/* — the Gemini SDK accepts the URL.
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
    `URLS:\n${req.urls.map((u) => `  - ${u}`).join("\n")}\n` +
    `QUESTION_COUNT: ${questionCount(req.questionCountHint)}\n\n` +
    `Build a form based on the fetched content below.\n\n` +
    blocks;

  return { text };
}

export function buildContents(args: BuildContentsArgs): Content[] {
  const { body, fetchedUrls } = args;

  let userParts: Part[];
  switch (body.inputType) {
    case "text":    userParts = [textTurn(body)]; break;
    case "pdf":     userParts = pdfTurn(body);    break;
    case "book":    userParts = bookTurn(body);   break;
    case "youtube": userParts = youtubeTurn(body); break;
    case "urls":    userParts = [urlsTurn(body, fetchedUrls ?? [])]; break;
  }

  return [
    ...FEW_SHOTS,
    { role: "user", parts: userParts },
  ];
}
