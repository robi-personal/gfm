# Product Requirements Document
## GFM — Mobile Google Forms Companion

**Version:** 1.0 (MVP)
**Last updated:** 2026-04-11
**Target audience:** Educational institutions — teachers, students, and administrative staff

---

## 1. Overview

GFM is a native Flutter mobile app that lets users create, edit, manage, share, and review Google Forms directly from their phone. It is a companion to Google Forms, not a replacement. Every form lives in the user's own Google Drive and remains a real Google Form — editable anywhere, owned by them, synced through official Google APIs.

**North-star metric:** A user can go from cold-launch to a published 5-question form with a share link in their clipboard in under 45 seconds.

---

## 2. Problem Statement

Google Forms is widely used in educational settings — for quizzes, assignments, surveys, event registrations, and feedback collection. However, the mobile browser experience at forms.google.com is slow, cramped, and not designed for phone use. Teachers cannot quickly build a quiz between classes. Staff cannot efficiently review responses on the go. Students checking their quiz results face a frustrating UI.

GFM solves this by providing a native, thumb-friendly interface that maps directly to the Google Forms API — giving educators the full power of Google Forms from a phone.

---

## 3. Target Users

| Role | Primary use cases |
|---|---|
| **Teachers** | Create quizzes with answer keys, review responses, share form links with students, export results as CSV |
| **Students** | Not the form-creator persona — students fill forms via browser. Students may use GFM to review quiz feedback if given editor access. |
| **Administrative staff** | Create surveys and registration forms, monitor responses, export data |

---

## 4. Goals

1. **Speed** — match or beat the 45-second cold-launch-to-published-form benchmark.
2. **Full fidelity** — support all question types and settings the Forms API exposes.
3. **Data ownership** — all forms live in the user's Google Drive; no data touches a third-party backend.
4. **Privacy-first** — never log form content or response data; comply with educational data handling expectations.
5. **Reliability** — optimistic UI with automatic retry; users should never lose a change silently.

---

## 5. Non-Goals (MVP)

- Offline queue / drift-backed pending writes
- IAP / paywall enforcement (UI exists but not gated)
- Duplicate form / duplicate question
- QR code generation
- Custom backend or server-side processing
- Any feature the Google Forms API does not support (see §10)

---

## 6. Features

### 6.1 Authentication
- Sign in with Google (OAuth 2.0)
- Silent sign-in on relaunch (cached credentials)
- Sign out with full session clear
- Scopes: `drive.file`, `forms.body`, `forms.responses.readonly`

### 6.2 Dashboard
- List all forms created by the app, sorted by last modified
- Search forms by name
- Create new form (name prompt → instant publish)
- Delete form (soft trash to Drive)
- Tap form → opens editor
- Shimmer loading skeleton
- Empty state with guidance copy
- Search empty state

### 6.3 Form Editor
- Edit form title and description (600ms debounce)
- Three-tab layout: Questions | Responses | Settings
- Save button with dirty-state detection
- Conflict detection (revision mismatch) with Keep/Load modal
- Reorder items via long-press drag
- Auto-scroll to newly added item

### 6.4 Question Management
- Add question (default: short answer)
- Delete question
- Edit question title, type, options, required toggle
- Type picker: 10 types across free and advanced tiers
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

### 6.6 Sections & Branching
- Add section headers (page break items)
- Text blocks (title + description only)
- Branching logic on Radio and Dropdown options: go to section / next section / restart / submit

### 6.7 Media Items
- **Image items** — paste a public URL or pick from device gallery (uploaded to Drive, set public)
- **YouTube video items** — search YouTube and insert

### 6.8 Form Settings
- Quiz mode toggle (with warning when disabling — grading is deleted)
- Email collection: off / verified (Workspace) / ask respondent
- Linked Google Sheet button (opens browser)
- "Edit in browser" link for unsupported settings

### 6.9 Quiz Mode
- Per-question point values
- Answer key editor (correct answers for choice and text questions)
- Feedback on correct / incorrect / general

### 6.10 Preview & Share
- Full-screen in-app webview of the responder URL
- Share via OS share sheet
- Copy link

### 6.11 Responses
- Summary tab: per-question aggregates (choice bars, numeric averages, text previews)
- Individual tab: paginated list of responses, tap for full detail
- Sorted newest-first
- Empty states with icons

### 6.12 CSV Export
- Fetches all responses via pagination
- Builds CSV with header row (Timestamp, Email, question titles)
- Shares via OS share sheet

### 6.13 Analytics & Crash Reporting
- Firebase Analytics: screen views + key events (form_created, form_opened, form_saved, question_added, image_added, video_added, responses_viewed, csv_exported)
- Firebase Crashlytics: automatic Flutter + async error capture
- User identity tied to Google account email (hashed in Crashlytics)

---

## 7. Error Handling Philosophy

- **No snackbars or toasts** — they get missed and leave users unsure if their work was saved.
- Four surfaces only: save-status pill, inline banner, error modal, full-screen error state.
- Automatic retry with exponential backoff (1s → 3s → 8s) for network/5xx failures.
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

---

## 9. Privacy & Data Handling

> **Important for educational context:**

- **No form content is logged** — question text, response data, and personally identifiable information are never sent to analytics or crash reporting services.
- **No custom backend** — all data flows directly between the user's device and Google's servers via official APIs.
- **Data stays in the user's Google Drive** — GFM never copies, stores, or processes form content on any third-party server.
- **OAuth scopes are minimal** — `drive.file` limits Drive access to files the app created; no access to the user's broader Drive.
- **Student data** — GFM is a form-creation tool used by teachers and staff. Students interact with forms through the standard Google Forms responder URL in a browser, not through GFM. GFM only reads response data for the form owner's review.
- **Compliance consideration** — institutions should verify that their Google Workspace for Education agreement covers API-based access to Forms data. FERPA compliance is the responsibility of the institution's Google Workspace administrator, not GFM.

---

## 10. Hard Limits — What the API Does Not Support

These features cannot be built and will not be faked:

1. File upload questions (API read-only; cannot create)
2. Limit to one response per person
3. Custom confirmation message
4. Response receipts / email-on-submit
5. Themes, colors, fonts, header images
6. Form-level question shuffle
7. Real-time collaboration
8. Submitting responses programmatically
9. Deleting individual responses
10. Updating an image item's content after creation

For items 2–5, a "Edit in browser" button opens the form's edit URL in the system browser.

---

## 11. Platform & Technical Constraints

- **Platforms:** iOS 13+, Android 6.0+ (API 23+)
- **Auth:** Google Sign-In (OAuth 2.0); requires Google account
- **Network:** Online-only for MVP (offline queue deferred)
- **Forms API:** `googleapis forms/v1`
- **Drive API:** `googleapis drive/v3`

---

## 12. Success Metrics

| Metric | Target |
|---|---|
| Cold launch → published form | < 45 seconds |
| Crash-free sessions | > 99% |
| Save success rate | > 99.5% |
| Daily active users (post-launch) | Track via Firebase Analytics |
| Forms created per session | Track via Analytics |
