# Product Requirements Document
## GFM — Mobile Google Forms Companion

**Version:** 1.3
**Last updated:** 2026-05-26
**Target audience:** Educational institutions — teachers, students, and administrative staff

---

## 1. Overview

GFM is a native Flutter mobile app that lets users create, edit, manage, share, and review Google Forms directly from their phone. It is a companion to Google Forms, not a replacement. Every form lives in the user's own Google Drive and remains a real Google Form — editable anywhere, owned by them, synced through official Google APIs.

The app is paired with a small Node middleware (`gfm_mw`) that handles AI form generation (via Gemini), quota tracking, RevenueCat subscription webhooks, and Google Forms push notifications via FCM. The middleware never stores form content or response data.

**North-star metric:** A user can go from cold-launch to a published 5-question form with a share link in their clipboard in under 45 seconds.

---

## 2. Problem Statement

Google Forms is widely used in educational settings — for quizzes, assignments, surveys, event registrations, and feedback collection. However, the mobile browser experience at forms.google.com is slow, cramped, and not designed for phone use. Teachers cannot quickly build a quiz between classes. Staff cannot efficiently review responses on the go. Students checking their quiz results face a frustrating UI.

GFM solves this by providing a native, thumb-friendly interface that maps directly to the Google Forms API — giving educators the full power of Google Forms from a phone.

---

## 3. Target Users

| Role | Primary use cases |
|---|---|
| **Teachers** | Create quizzes with answer keys, review responses, share form links with students, export results as CSV / PDF, get push notifications on new submissions |
| **Students** | Not the form-creator persona — students fill forms via browser. Students may use GFM to review quiz feedback if given editor access. |
| **Administrative staff** | Create surveys and registration forms, monitor responses, export data |

---

## 4. Goals

1. **Speed** — match or beat the 45-second cold-launch-to-published-form benchmark.
2. **Full fidelity** — support all question types and settings the Forms API exposes; shell out to the Google Forms web editor for the few features the API does not (file upload questions, response-per-person, etc.).
3. **Data ownership** — all forms live in the user's Google Drive; no form content is stored on the middleware.
4. **Privacy-first** — never log form content or response data; comply with educational data handling expectations.
5. **Reliability** — optimistic UI with automatic retry; users should never lose a change silently.

---

## 5. Non-Goals (MVP)

- Offline queue / drift-backed pending writes
- Duplicate form / duplicate question
- QR code generation

---

## 6. Features

### 6.1 Authentication
- Sign in with Google (OAuth 2.0)
- Silent sign-in on relaunch (cached credentials)
- Sign out with full session clear (Drive/Forms clients, in-app WebView cookies, RC `logOut`)
- Scopes: `drive.file`, `forms.body`, `forms.responses.readonly`

### 6.2 Dashboard
- List forms owned by the user (Drive `files.list`) **and** imported forms (tracked in a per-user `gfm_data.json` appdata file)
- Grouped by Today / This Week / Earlier; tap to open editor
- Search forms by name (debounced)
- Create new form via FAB → name prompt → instant publish
- Create from template gallery (17 templates across Work / Personal / Education, including a Blank Quiz)
- **Import existing form** via in-app Google Drive WebView — taps a form tile in Drive search and captures its `data-id`
- Rename / delete from kebab menu
- Side drawer: Create section (AI Builder, New, Template, Import), Subscription, Support Us (Share / Rate), Policy (Privacy / Terms), Sign Out
- Shimmer skeleton, empty state, search-empty state

### 6.3 Form Editor
- Three-tab layout: Questions | Responses | Settings (segmented pill)
- Edit form title and description
- Save chip in app bar; dirty-state detection across pending creates / deletes / edits / reorders
- Conflict detection (revision mismatch) with Keep/Load modal
- Reorder items via long-press drag (`ReorderableDelayedDragStartListener`)
- Auto-scroll to newly added item
- Discard-changes confirmation on system back / app bar back when dirty

### 6.4 Question Management
- Add question via bottom action bar (Question / Image / Text / Video / Section)
- Draft mode — `+` opens the edit sheet on an in-memory item; Done commits, dismiss discards
- Delete question
- Edit question title, description, type, options, required toggle, point value (in quiz mode)
- Type picker: iOS-style card tiles in two groups (Common / Advanced)
- Inline type switcher preserving title and compatible options

### 6.5 Question Types
| Type | Notes |
|---|---|
| Short answer | Default type |
| Paragraph | Multi-line text |
| Multiple choice | Radio buttons |
| Checkboxes | Multi-select |
| Dropdown | Select list |
| Linear scale | Min/max labels |
| Date | With optional time and year |
| Time / Duration | |
| Rating | 3–10 levels, Star / Heart / Thumb icons |
| Multiple-choice grid | Row × column questions |
| Checkbox grid | Multi-select grid |
| File upload | **Created and edited via the Google Forms web editor in an in-app WebView** — the Forms API does not support this type. Existing file-upload questions are rendered read-only in the editor. |

### 6.6 Sections & Branching
- Add section headers (page break items)
- Text blocks (title + description only)
- Branching logic on Radio and Dropdown options: go to section / next section / restart / submit

### 6.7 Media Items
- **Image items** — paste a public URL or pick from device gallery (uploaded to Drive, set public, used as `sourceUri`)
- **YouTube video items** — search YouTube and insert via `VideoItemContent`

### 6.8 Form Settings
- Quiz mode toggle (with warning when disabling — grading is deleted)
- Email collection: off / verified (Workspace) / ask respondent
- Linked Google Sheet button (opens browser)
- **Extended settings via Apps Script** — shuffle questions, limit one response per user, allow response edits, confirmation message (delegated to a user-bound Apps Script web app)
- Per-form **push notification toggle** — creates a Google Forms `watch` and routes Pub/Sub deliveries to FCM (premium-gated)

### 6.9 Quiz Mode
- Per-question point values
- Answer key editor (correct answers for choice and text questions)
- Feedback on correct / incorrect / general

### 6.10 Preview & Share
- Full-screen in-app webview of the responder URL
- Share via OS share sheet
- Copy link

### 6.11 Responses
- Summary sub-tab: per-question aggregates (proportional choice bars, numeric averages, text previews)
- Individual sub-tab: paginated list of responses, tap for full detail
- Sorted newest-first; response-count badge on the Responses tab
- Empty states with icons
- **Push notification on submit** — tap deep-links into the Responses tab of the originating form

### 6.12 Export
- **CSV export** — fetches all responses via pagination → builds CSV (Timestamp, Email, question titles) → `Share.shareXFiles`. Premium-gated via server `/user/status`.
- **PDF export** — four formats chosen via bottom sheet (Questionnaire / Table / Summary / Individual). Built locally using the `pdf` package and opened in the OS print dialog via `printing` (AirPrint on iOS, Mopria/IPP on Android).

### 6.13 AI Form Builder (Premium for non-text inputs)

- Input types: free-text prompt (all users), PDF upload / YouTube URL / website URLs / book chapter PDF (premium-gated)
- Question count picker: 3–50 questions (editable field + −/+ buttons; default 5)
- AI auto-detects quiz vs. form intent — no UI toggle required (prompt v3)
- Generated forms include answer keys and grading when quiz is detected
- **Quota system (balance-based):** server tracks `quota_balance` per user; free users get 3/month, premium plans credit 15/50/700 per Weekly/Monthly/Yearly (configurable per-product)
- Whitelisted accounts (developer/testers and App Store reviewers) bypass quota entirely and are treated as full premium
- Pre-flight quota check for PDF/book — `/ai/pdf-page-count` returns `quotaCost = ceil(pages / PDF_PAGES_PER_QUOTA)`; client sends `confirmedQuotaCost` on `/ai/generate`, server returns 409 if it has changed since the pre-flight

### 6.14 Premium / Paywall

- Subscription plans via RevenueCat: Weekly ($3.99), Monthly ($4.99), Annual ($44.99 — "Save 78%")
- Entitlement `GFMPremium`; offering `default`; product IDs `GFM_Weekly_3.99`, `GFM_Monthly_4.99`, `GFM_Yearly_44.99`
- Premium unlocks: CSV export, premium AI input types (PDF / YouTube / URLs / book), higher quota grants, per-form push notifications, server-side **YouTube minutes** budget
- Paywall shown on: CSV export attempt (non-premium), AI quota exhausted, locked input type tap, drawer "Upgrade Plan"
- Restore Purchases syncs existing subscription from App Store / Play Store
- **Server is single source of truth.** Premium gating uses `/user/status` (not the RC SDK). The RC webhook is reconciled by an app-triggered `POST /user/purchase/sync` immediately after a successful purchase to shrink the window where the webhook hasn't arrived yet.
- Apple `original_transaction_id` is bound to a single Google account in the DB (`apple_subscription_bindings`); a second account attempting the same Apple ID is blocked by `POST /user/apple/check` before the purchase starts.
- Post-purchase polling: app polls `/user/status` up to 6× (≈24s) to flip UI to premium without waiting on webhook latency.

### 6.15 Push Notifications

- iOS + Android via Firebase Cloud Messaging (FCM)
- Per-form opt-in toggle in the Settings tab (premium-gated)
- Google Forms `watch` created via Forms API → response submission → Pub/Sub push delivery → middleware → FCM fan-out to all of the user's registered device tokens → notification tap deep-links into the Responses tab
- Permission rationale shown post-sign-in (soft-ask), then OS prompt on accept
- Watches expire after 7 days (Forms API limit); no auto-renewal — user re-enables manually

### 6.16 Analytics & Crash Reporting
- Firebase Analytics: screen views + key events (`form_created`, `form_opened`, `form_saved`, `question_added`, `image_added`, `video_added`, `responses_viewed`, `csv_exported`)
- Firebase Crashlytics: automatic Flutter + async error capture
- User identity tied to Google account email (hashed in Crashlytics)

---

## 7. Error Handling Philosophy

- **No snackbars or toasts** — they get missed and leave users unsure if their work was saved.
- Four surfaces only: save-status pill, inline banner, `ErrorModal`, full-screen error state.
- `ErrorModal` is the single funnel for all confirms and errors (iOS-style modal: rounded white card, purple primary CTA pill).
- Automatic retry with exponential backoff (1s → 3s → 8s) for network / 5xx failures.
- Revision mismatch: silent retry once; second failure → user modal with Keep/Load choice.
- All errors use plain language — no HTTP codes, no exception names, no apologies.

---

## 8. UX Principles

1. No empty state during creation — new form has one question with title focused.
2. Default question type is short answer.
3. Optimistic UI — every edit updates local state immediately.
4. Primary actions (add, save, share) live in the bottom 25% of the screen.
5. Long-press to reorder questions.
6. One-tap share from the editor.
7. iOS-style bottom sheets (import info, rename, delete, format picker) — no Material `AlertDialog`s.

---

## 9. Privacy & Data Handling

> **Important for educational context:**

- **No form content is logged** — question text, response data, and personally identifiable information are never sent to analytics or crash reporting services.
- **Middleware never stores form content.** `gfm_mw` stores: user identity (Google `sub`, email), quota balance, subscription product, FCM device tokens, Forms watch IDs, RC webhook event audit log, AI generation audit (input hash + output JSON in `ai_generations` for idempotency caching — TTL'd by `cleanup_expired_generations.sql`).
- **Form data stays in Google Drive** — GFM never copies or stores form content or response data on any backend server. Push notifications carry only the form title and the fact that a new response arrived — never the response content.
- **OAuth scopes are minimal** — `drive.file` limits Drive access to files the app created (and forms the user explicitly imports). No access to the user's broader Drive.
- **Student data** — GFM is a form-creation tool used by teachers and staff. Students interact with forms through the standard Google Forms responder URL in a browser, not through GFM. GFM only reads response data for the form owner's review.
- **Compliance consideration** — institutions should verify that their Google Workspace for Education agreement covers API-based access to Forms data. FERPA compliance is the responsibility of the institution's Google Workspace administrator, not GFM.

---

## 10. Hard Limits — What the API Does Not Support

These features cannot be built via the Forms API. Where possible, GFM shells out to the Google Forms web editor in an in-app WebView (`EditFormWebViewPage`) rather than faking them.

| Feature | Handling |
|---|---|
| File upload questions | In-app WebView to Forms web editor for create + edit |
| Limit to one response per person | Apps Script (extended settings) |
| Shuffle questions | Apps Script |
| Allow response edits after submit | Apps Script |
| Custom confirmation message | Apps Script |
| Response receipts / email-on-submit | Not implemented |
| Themes, colors, fonts, header images | Not implemented |
| Real-time collaboration | Not implemented |
| Submitting responses programmatically | Not implemented |
| Deleting individual responses | Not implemented |
| Updating an `imageItem`'s content after creation | Delete + recreate |

---

## 11. Platform & Technical Constraints

- **Platforms:** iOS 13+, Android 6.0+ (API 23+)
- **iOS bundle ID:** `com.rashed.gfm`
- **Android applicationId:** `com.app.formmanager`
- **Auth:** Google Sign-In (OAuth 2.0); requires Google account
- **Network:** Online-only for MVP (offline queue deferred)
- **Forms API:** `googleapis forms/v1` (Dart `googleapis ^16.0.0`)
- **Drive API:** `googleapis drive/v3`
- **Middleware:** `https://gfm.robi-dev.tech` (VPS `177.7.51.7`, Hostinger)

---

## 12. Success Metrics

| Metric | Target |
|---|---|
| Cold launch → published form | < 45 seconds |
| Crash-free sessions | > 99% |
| Save success rate | > 99.5% |
| Daily active users (post-launch) | Track via Firebase Analytics |
| Forms created per session | Track via Analytics |
