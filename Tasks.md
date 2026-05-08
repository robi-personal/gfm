# Phase 2 — AI Form Builder (Flutter)

Flutter-side implementation of the AI Form Builder feature.
Spec docs: `docs/feature-spec-flutter.md`, `docs/api-contract.md`.
Work in order; each task builds on the previous.

---

## Tasks

| # | Task | Model | Depends on | Status |
|---|------|-------|------------|--------|
| 1 | Domain entities — `GeneratedForm`, `UserStatus`, `QuotaSnapshot` | **Sonnet 4.6** | — | ✅ |
| 2 | Repository interface + use cases (`GetUserStatus`, `GenerateForm`, `CreateFormFromAi`) | **Sonnet 4.6** | 1 | ✅ |
| 3 | `AiFormDataSource` — HTTP layer (`GET /user/status`, `POST /ai/generate`, all 5 input types, ID token auth) | **Sonnet 4.6** | 1 | ✅ |
| 4 | `AiFormRepositoryImpl` + DI wiring in `injection.dart` | **Sonnet 4.6** | 2, 3 | ✅ |
| 5 | Cubit + sealed state machine (all 6 states, idempotency key lifecycle, retry logic, side-effect events) | **Opus 4.7** | 4 | ✅ |
| 6 | `AiFormBuilderPage` — free-tier UI (text input, quota counter, generate button, loading phases) | **Sonnet 4.6** | 5 | ✅ |
| 7 | `AiFormBuilderPage` — premium additions (input type picker, PDF file picker, YouTube URL, URLs list, Book) | **Opus 4.7** | 6 | ⬜ |
| 8 | Error handling — all 20+ error codes → `ErrorModal` or `PaywallPage.show()` (full §4 table) | **Sonnet 4.6** | 5 | ⬜ |
| 9 | `AiFormPreviewPage` — show generated questions, "Create Form" button | **Sonnet 4.6** | 5 | ✅ |
| 10 | `CreateFormFromAi` use case — `forms.create` → `setPublishSettings` → `batchUpdate` with AI→Forms API mapping for all 9 question types | **Opus 4.7** | 2, 9 | ✅ |
| 11 | Dashboard entry point — add AI builder trigger (FAB long-press or app bar icon) | **Sonnet 4.6** | 6 | ✅ |

---

## Model rationale

- **Opus 4.7** for tasks where a mistake is hard to undo or affects every user:
  - Task 5 — cubit state machine has idempotency key semantics, retry behaviour, and side-effect event streams; a subtle bug here double-charges or loses results
  - Task 7 — PDF file picker involves platform-specific file encoding, local size validation before upload, and multi-variant input UI
  - Task 10 — multi-step form creation pipeline coordinates three API calls in sequence; wrong AI→Forms API mapping silently creates broken forms

- **Sonnet 4.6** for everything else — all decisions are fully specified in `docs/feature-spec-flutter.md`; implementation is mechanical

---

## Key spec references per task

| Task(s) | Spec doc / section |
|---------|--------------------|
| 1, 2, 3 | `docs/api-contract.md` §3 (schemas), §4 (endpoint behaviour) |
| 5       | `docs/feature-spec-flutter.md` §2 (cubit state machine) |
| 6, 7    | `docs/feature-spec-flutter.md` §3 (free vs premium UI), §5 (loading states) |
| 8       | `docs/feature-spec-flutter.md` §4 (error → UI map) |
| 9       | `docs/feature-spec-flutter.md` §1.2 (navigation), §2.2 (happy path) |
| 10      | `docs/feature-spec-flutter.md` §7.4 (on-success flow), §7.5 (AI enum → Forms API shape) |
| 11      | `docs/feature-spec-flutter.md` §1.2 (navigation graph, dashboard entry point) |

---

## Architecture decisions (carry-forward)

- **State management:** `flutter_bloc` Cubits — not Riverpod
- **Clean arch layers:** domain / data / presentation, mirroring `dashboard` and `editor`
- **Feature directory:** `lib/features/ai_form_builder/` (confirm with user before creating)
- **Auth:** reuse `_GoogleAuthClient` pattern from `lib/core/auth/google_auth_datasource.dart`
- **Form creation:** reuse existing `EditorDataSource` methods — do not duplicate API calls
- **No direct Gemini calls:** app always calls the middleware; never calls Gemini or Google AI directly
