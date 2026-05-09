# Tasks

## 1. Add description field to input types (PDF, YouTube, URLs, Book)
- Add `_descriptionController` to `ai_form_builder_page.dart`
- Inject description TextField below each input area (pdf, youtube, urls, book)
- Pass `description` in submit map for each input type
- Add `description: z.string().max(2000).optional()` to all 4 request types in `request-schema.ts`
- Inject `USER_INTENT` line in pdfTurn, youtubeTurn, urlsTurn, bookTurn in `build-contents.ts`
- Remove chapter title field from Book input in `ai_form_builder_page.dart`
- Remove `chapterTitle` from `BookRequest` schema in `request-schema.ts` and `bookTurn` in `build-contents.ts`

## 2. YouTube minute cap
- Add `youtube_minutes_used` and `youtube_minutes_reset_at` columns to users table
- Add `YOUTUBE_API_KEY` to env and `src/config/env.ts`
- Create `src/ai/youtube-duration.ts` — fetch duration from YouTube Data API v3, parse ISO 8601 → minutes (ceil)
- Create `src/presentation/middleware/youtube-minutes.middleware.ts` — check monthly cap, attach `req.videoDurationMinutes`, reject with `youtube_minutes_exceeded`
- Add `getYoutubeMinutesUsed`, `incrementYoutubeMinutes`, `resetYoutubeMinutesIfNeeded` to user repository
- Wire middleware in `ai.routes.ts`, deduct minutes after successful generation
- Handle `youtube_minutes_exceeded` error in Flutter
- Add `youtubeMinutesUsed` and `youtubeMinutesLimit` to `getQuotaSnapshot()` response
- Add `youtubeMinutesUsed` and `youtubeMinutesLimit` to `QuotaSnapshot` entity in Flutter
- Show remaining YouTube minutes below the URL field when YouTube tab is selected

## 3. Improve URL HTML content extraction
- Replace `sanitizeHtml` with `@mozilla/readability` in `url-fetcher.ts`
- Extract main article content only — strip nav, footer, ads, scripts
