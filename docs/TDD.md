# Technical Design Document
## GFM — Mobile Google Forms Companion

**Version:** 1.3
**Last updated:** 2026-05-26

---

## 1. Tech Stack

### Flutter (client)

| Layer | Technology |
|---|---|
| Client framework | Flutter (stable channel), Dart 3.x |
| State management | `flutter_bloc` / Cubit (one cubit per feature) |
| Google APIs | `googleapis ^16.0.0` (forms/v1, drive/v3) |
| Authentication | `google_sign_in ^6.x`, `googleapis_auth` |
| Dependency injection | `get_it` (manual registration; no codegen runtime) |
| Serialization | `freezed` + `json_serializable` for plain models; manual sealed classes for the Forms API discriminated unions (`QuestionKind`, `ItemContent`) |
| Local storage | `flutter_secure_storage` (Google `sub` for WebView session keying), `shared_preferences` (rating prompt state) |
| Sharing | `share_plus` |
| Web view | `flutter_inappwebview` (Drive import, Forms editor for file-upload, in-app legal pages), `webview_flutter` (read-only preview) |
| Image / file picking | `image_picker`, `file_picker` |
| HTTP | Provided by `googleapis_auth` for Google APIs; `package:http` for the middleware |
| Analytics | `firebase_analytics ^11.x` |
| Crash reporting | `firebase_crashlytics ^4.x` |
| Push | `firebase_messaging ^15.x`, `flutter_local_notifications ^18.x` |
| Subscriptions | `purchases_flutter ^10.x` (RevenueCat v10), `purchases_ui_flutter ^10.x` |
| PDF | `pdf ^3.x` (build), `printing ^5.x` (OS print dialog) |
| Misc | `flutter_svg`, `shimmer`, `intl`, `dartz` (Either), `url_launcher`, `in_app_review` |

> `drift` is declared in `pubspec.yaml` but is not currently wired anywhere in `lib/`. Treat as dormant.

### Middleware (`gfm_mw`)

| Layer | Technology |
|---|---|
| Runtime | Node.js 20 + TypeScript |
| Framework | Express 4 |
| Database | PostgreSQL (via `pg` pool) |
| Cache / rate limiting | Redis (via `ioredis`) + `rate-limiter-flexible` |
| AI | Google Gemini `gemini-2.5-flash-lite` via `@google/generative-ai`. Provider is swappable (`AI_PROVIDER=gemini\|openrouter`); wire-level error codes stay `gemini_*` either way. |
| Auth | `google-auth-library` — verifies Google ID tokens against both web and iOS client IDs |
| FCM | `firebase-admin` — multicast send, returns invalid tokens for cleanup |
| Pub/Sub OIDC | `google-auth-library` token verification on incoming Forms-watch deliveries |
| HTTP fetching (URL inputs) | Native `fetch` with SSRF guards (`ipaddr.js`), HTML sanitization via `@mozilla/readability` + `jsdom` + `sanitize-html`, PDF parsing via `pdf-lib` |
| Logging | `pino` (JSON to stdout) |
| Metrics | `prom-client` (`/metrics` for Prometheus scrape) |
| Errors | `@sentry/node` |
| Validation | `zod` |
| Tests | `vitest` + `supertest` |
| Admin UI | React + Vite (`gfm_mw/admin/`), built to `dist/admin-dist` and served from the same Express app |
| Deployment | Docker Compose + `./deploy.sh` → VPS `root@177.7.51.7`; Nginx reverse proxy + Let's Encrypt on `gfm.robi-dev.tech` |

---

## 2. Project Structure

### Flutter

```
lib/
  main.dart                          Firebase init, RC configure, DI, NotificationService.init (async), runApp
  app.dart                           MaterialApp + AnalyticsObserver + SignInCubit gate (Splash / SignIn / Dashboard)
  firebase_options.dart              Auto-generated

  core/
    api/
      forms_client.dart              Lazy singleton wrapping FormsApi (resets on sign-out)
      drive_client.dart              Lazy singleton wrapping DriveApi + uploadImage()
      apps_script_client.dart        Calls user's deployed Apps Script web app for extended settings
      concurrency.dart               runBatchUpdate() + isRevisionMismatch()
    auth/
      google_auth_datasource.dart    GoogleSignIn + _GoogleAuthClient (OAuth header injection)
    di/injection.dart                get_it registrations for all features
    error/failure.dart               Sealed Failure hierarchy (incl. QuotaExceededFailure)
    models/                          FormDoc, Item, ItemContent (sealed 6 variants), Question,
                                     QuestionKind (sealed 8 variants), ChoiceOption (freezed),
                                     FormResponse, enums
    services/
      analytics_service.dart         Static wrappers around Analytics + Crashlytics
      rating_service.dart            Tracks generations completed; triggers in_app_review prompt
      webview_session_manager.dart   Clears WebView cookies/storage on Google-sub change
    theme/                           AppColors / AppTextStyles / AppShapes (design tokens)
    design.dart                      Barrel export for the design system
    widgets/
      error_modal.dart               The only place errors are shown
      simple_web_view_page.dart      Reusable in-app WebView (Privacy / Terms)
      skeleton_bone.dart             Shimmer building block
      brand_mark.dart                28px logo tile

  features/
    sign_in/                         Auth feature (clean arch — domain / data / presentation)
    dashboard/                       Form list, drawer, templates, import
      data/datasources/              drive_datasource.dart, forms_datasource.dart
      domain/usecases/               get/create/delete/rename + get/import/remove imported form
      presentation/                  cubit + page + widgets/ (dashboard_header, form_list, drawer, fab, dialogs, …)
      presentation/pages/            dashboard_page.dart, import_form_webview_page.dart,
                                     template_picker_page.dart, template_data.dart
    editor/
      data/                          editor_datasource (raw API), repositories/, pdf_builders.dart
      domain/usecases/               load_form, execute_batch, refresh_revision, update_editor_settings,
                                     get_responses
      presentation/pages/            editor_page.dart, edit_form_webview_page.dart, preview_screen.dart
      presentation/pages/tabs/       questions/, responses/, settings/ — each with its own cubit + widgets
      presentation/widgets/          editor_nav_rail, editor_skeleton, editor_tab_bar,
                                     editor_options_sheet, toggle_confirm_sheet
    ai_form_builder/
      data/datasources/              ai_form_datasource.dart (HTTP to middleware, Google ID-token auth)
      data/repositories/             ai_form_repository_impl.dart (Forms API create + grading + quiz-mode)
      data/services/                 user_status_service.dart (cache + poll)
      domain/                        entities (UserStatus, GeneratedForm, AiQuestion, AiGrading,
                                     QuotaSnapshot), repositories, usecases (get_user_status,
                                     generate_form, create_form_from_ai)
      presentation/                  cubit + page + widgets (input picker, quota counter, generate button…)
    paywall/
      data/services/                 subscription_service.dart (RC SDK wrapper),
                                     purchase_activation_service.dart (calls /user/purchase/sync),
                                     apple_subscription_channel.dart (native channel for original_transaction_id)
      presentation/                  subscription_cubit.dart + paywall_page.dart
    notifications/
      data/datasources/              notifications_api.dart (HTTP to middleware: devices, watches, syncPurchase)
      data/services/                 notification_service.dart (FCM init, APNs wait, perm rationale,
                                     local notifications, tap stream)
```

### Middleware (`gfm_mw/src/`)

```
server.ts                            Sentry init → runMigrations → configService.load → initFcm → listen
app.ts                               Express wiring; trust proxy 1, body limit 8MB, route mounts, Sentry handler
config/
  env.ts                             Zod-validated process.env
  config-service.ts                  DB-backed mutable config (loaded once at startup, refreshable)
ai/                                  System prompt (v3), few-shots, schemas (request/response/simple/form),
                                     normalizer, canonicalize, auto-repair, repair-policy, build-contents,
                                     generator, pdf-pages, youtube-duration
domain/                              Pure entities + repository interfaces
infrastructure/
  db/                                postgres pool, migrate.ts, pg-*.repository.ts
  google-auth/                       google-token-verifier (web + iOS audiences), pubsub-token-verifier
  gemini/                            gemini-client (gemini-2.5-flash-lite)
  ai/                                Provider abstraction (gemini-provider, openrouter-provider, index)
  fcm/                               fcm.service.ts (Firebase Admin SDK; accepts raw or base64 JSON SA)
  url-fetcher/                       SSRF-safe HTTP fetcher
  redis/                             Shared ioredis client
  logger.ts, metrics.ts
application/
  rc-webhook/apply-event.ts          Pure handler for all 7 RC event types; called from webhook route and
                                     from auth-middleware orphan-replay
presentation/
  middleware/                        request-id, logging, error, auth, admin-auth, rc-webhook-auth,
                                     premium, rate-limit (Redis), kill-switch, youtube-minutes
  routes/                            ai, user, devices, watches, webhook, admin, health
admin/                               React + Vite admin UI (Quota Products, Whitelist, Kill Switches,
                                     Rate Limits, YouTube, Documents, Notifications, Login)
migrations/                          001..008 SQL — see §13
apps-script/Code.gs                  applySettings() — deployed by user to their own Apps Script project
```

---

## 3. Architecture

### 3.1 Clean architecture (per feature)

```
Presentation  →  Domain  →  Data
(Cubit/Pages)    (UseCases/   (DataSources/
                  Entities/    RepositoryImpls)
                  Repositories)
```

Applied throughout `sign_in`, `dashboard`, `editor`, `ai_form_builder`. Paywall and notifications are simpler (no domain layer — services + cubit).

### 3.2 State management

`flutter_bloc` Cubits. State is an immutable sealed class. The editor page splits its state across **three independent tab cubits** (`QuestionsCubit`, `ResponsesCubit`, `SettingsCubit`) plus `ExtendedSettingsCubit` for the Apps Script bridge, all provided via `MultiBlocProvider`. `BlocSelector` and `buildWhen` guards prevent unnecessary rebuilds.

### 3.3 Dependency injection

`get_it` with manual registrations in `lib/core/di/injection.dart`. All singletons are lazy. Cubits are registered as factories (new instance per screen push). DI is initialized in `main.dart` before `runApp`.

---

## 4. Authentication

### 4.1 OAuth scopes

```
https://www.googleapis.com/auth/drive.file
https://www.googleapis.com/auth/forms.body
https://www.googleapis.com/auth/forms.responses.readonly
```

- `drive.file` — non-sensitive. Restricts Drive access to files the app created **and** files the user imports/opens in the picker. Covers image uploads and the per-user `gfm_data.json` appdata file.
- `forms.body` — sensitive. Verified by Google.
- `forms.responses.readonly` — sensitive. Verified by Google.

### 4.2 Auth client

`_GoogleAuthClient extends http.BaseClient` intercepts every HTTP request and injects `Authorization: Bearer <token>`. Token refresh is handled automatically by `google_sign_in`. The same client is passed to `FormsApi` and `DriveApi`, and reused by `AiFormDataSource` / `NotificationsApi` for middleware calls.

### 4.3 Server-side ID-token verification

`google-token-verifier.ts` accepts ID tokens with audience matching **either** `GOOGLE_CLIENT_ID` (web) **or** `GOOGLE_IOS_CLIENT_ID` (iOS). Removing `GOOGLE_IOS_CLIENT_ID` breaks iOS sign-in because `google_sign_in` on iOS issues tokens with the iOS client ID as audience.

### 4.4 Session management

After sign-in:
- `AnalyticsService.setUser(email)` + `FirebaseCrashlytics.setUserIdentifier(email)`
- `SubscriptionService.identifyUser(googleId)` → `Purchases.logIn(sub)` (NOT email — RC `app_user_id` must equal `users.google_sub` so webhooks resolve correctly)
- `WebViewSessionManager.syncWithUser(googleSub)` clears WebView cookies on account switch
- `NotificationService.registerForUser()` after rationale modal accept

After sign-out: `FormsClient.reset()`, `DriveClient.reset()`, `DriveDataSource.reset()` (clears cached `gfm_data.json` file ID), `Purchases.logOut()`, `NotificationService.unregisterForUser()`, analytics user cleared.

---

## 5. Domain models

### 5.1 Serialization approach

The Forms API uses **key-presence dispatch** — a JSON object has `textQuestion` or `choiceQuestion` etc., never a `type` field. `QuestionKind` and `ItemContent` are hand-written sealed classes with manual `fromJson` / `toJson`. All other models use `freezed`.

### 5.2 Critical serialization quirk

`googleapis` `Form.toJson()` puts nested Dart objects directly in the map (not plain `Map<String, dynamic>`). Fix in `EditorDataSource.getForm`:

```dart
final clean = jsonDecode(jsonEncode(apiForm.toJson())) as Map<String, dynamic>;
return FormDoc.fromJson(clean);
```

### 5.3 Null-stripping

`freezed` `toJson()` includes `null` fields; `googleapis` `fromJson` crashes on nulls. All API request bodies are passed through `removeNulls(map)` before `forms_api.Item.fromJson`.

### 5.4 Known null-value workarounds

Google sometimes returns `null` for `value` on `ChoiceOption` (e.g. "Other") and on `CorrectAnswer` entries. Both `choice_option.g.dart` and `grading.g.dart` coerce `json['value'] as String? ?? ''`.

---

## 6. API write pattern

### 6.1 batchUpdate flow

Every form mutation goes through `EditorRepositoryImpl.batchUpdate`:

1. First attempt with `WriteControl.requiredRevisionId = _revisionId`
2. On revision mismatch (400 `ABORTED`): fetch fresh revision, retry once
3. Second mismatch: `Left(RevisionMismatchFailure())` → cubit shows conflict modal
4. Non-revision 400: `Left(ServerFailure())` immediately — no retry
5. Network / 5xx: exponential backoff 1s → 3s → 8s

### 6.2 Deferred save

All changes accumulate in `PendingChanges` until the user taps Save:

| Change type | Storage |
|---|---|
| Title / description | Latest value (last write wins) |
| Add item | Ordered list of `PendingCreate` with temp IDs |
| Delete item | Set of real item IDs |
| Edit item content | Map of item ID → mutated Item (last write wins per item) |
| Reorder | Derived at flush time from final order vs `serverItemOrder` |

### 6.3 Save flush order

1. `updateFormInfo` (title/desc)
2. Creates — sequential; capture real server IDs from responses
3. Refresh revision + `serverItemOrder`
4. Deletes — descending index order (avoids index shift)
5. Edits — batch (real IDs substituted for temp IDs from `tempIdMap`)
6. Moves — diff final local order vs simulated server order
7. `_silentRefresh` — replace local `FormDoc` with clean server state

### 6.4 Discard guard

The editor `Scaffold` is wrapped in `PopScope(canPop: false)`. Both system back gesture and the app-bar back button route through `_handleBackPress`, which shows `ErrorModal("Discard changes?")` when `isDirty` and only pops on Discard.

---

## 7. Drive image upload

```
image_picker.pickImage(gallery)
  → XFile.readAsBytes() → Uint8List
  → DriveClient.uploadImage(bytes, mimeType)
      → DriveApi.files.create(metadata, uploadMedia: Media(stream, length, contentType))
      → DriveApi.permissions.create(Permission(type: anyone, role: reader), fileId)
      → return 'https://drive.google.com/uc?id=$fileId&export=view'
  → EditorCubit.addImageItem(url)
```

iOS permission required: `NSPhotoLibraryUsageDescription` in `Info.plist`.
Scope: `drive.file` (already in use).

---

## 8. File-upload questions via WebView

The Forms API cannot create or edit `fileUploadItem`. GFM shells out:

- **Create:** type picker → "File upload" → in-sheet explainer (`_FileUploadPromptPanel`) → Continue → push `EditFormWebViewPage`.
- **Edit:** pencil on an existing file-upload card → `ErrorModal` → push `EditFormWebViewPage`.

`EditFormWebViewPage` loads the form's edit URL in `flutter_inappwebview` and hides Forms' fixed top chrome via injected CSS (`.vDIOnd, .MBLJ9d { display: none !important; }` + `.KP7TGc { top: 0 !important; }`). On pop, `EditorCubit.refreshFromServer()` reloads the form.

The Drive import flow uses the same WebView library against `drive.google.com/drive/u/0/search?q=type:form` with a Safari user-agent, a CSS-injected hide of the Drive search header, and a document-level click handler that walks up the DOM looking for `data-id` / `data-target-id` / `data-document-id` and calls back into Flutter via `flutter_inappwebview.callHandler('FormTap', id)`.

`WebViewSessionManager` clears the WebView cookie jar when the signed-in Google `sub` changes, so user A's Drive doesn't leak into user B's import view.

---

## 9. Error architecture

### 9.1 Failure hierarchy

```dart
sealed class Failure
  NetworkFailure
  AuthFailure(message)
  AuthCancelledFailure
  ServerFailure(message)
  NotFoundFailure
  PermissionFailure
  RevisionMismatchFailure
  QuotaExceededFailure(balance, quotaCost, tier)
```

### 9.2 Error surfaces

| Surface | When |
|---|---|
| Save-status pill | Silent retry in progress |
| Inline banner | Ambient degraded state |
| `ErrorModal` (custom iOS-style) | User-actionable failure needing acknowledgement |
| Full-screen error | Screen cannot render anything useful |

**No snackbars. No toasts.** `ErrorModal.show()` is the only path.

---

## 10. Analytics

All calls go through `AnalyticsService` (static methods). Events: `form_created`, `form_opened`, `form_saved`, `question_added`, `image_added` (with `source: url|gallery`), `video_added`, `responses_viewed`, `csv_exported`. Screen views via `FirebaseAnalyticsObserver` in `App.navigatorObservers`.

**What is NOT logged:** form titles, question text, response content, answer data, OAuth tokens, prompt content.

---

## 11. Subscription & quota

### 11.1 RevenueCat

Configured in `SubscriptionService`:

- App ID: `appl_MkzXtKeEEhIYCwtQEgOdWquRCGK`
- Entitlement: `GFMPremium`
- Offering: `default`
- Products: `GFM_Weekly_3.99`, `GFM_Monthly_4.99`, `GFM_Yearly_44.99`

`SubscriptionCubit` orchestrates load → select → purchase → success/error/restore. After a successful purchase the cubit calls `PurchaseActivationService.syncPurchase()` → `POST /user/purchase/sync` so the server reconciles even if the RC webhook hasn't fired yet (see `purchase-flow.md` §3 for the full race analysis).

**Premium gating rule:** never check `SubscriptionService.isPremium()` for feature access. Always use `/user/status` (`GetUserStatus`) — that respects the whitelist override and the server's view of quota state. The RC SDK is only used inside the cubit for purchase/restore.

### 11.2 Apple subscription binding

`apple_subscription_bindings` table maps `original_transaction_id` → `user_id` permanently. Before starting a purchase, the app calls `POST /user/apple/check` with the StoreKit-fetched `original_transaction_id` (via `AppleSubscriptionChannel`). If the transaction is already bound to a different account, the app shows a dialog and refuses to start the purchase. Prevents the "one Apple ID, multiple Google accounts, multiple quota grants" abuse path.

### 11.3 Quota

Quota is tracked server-side in PostgreSQL:

| Table | Purpose |
|---|---|
| `quota_products` | Per-product quota grant (free: 3, weekly: 15, monthly: 50, yearly: 700; tunable in admin) |
| `quota_transactions` | Immutable audit log of every credit/debit |
| `quota_whitelist` | Emails that bypass quota gates and are treated as full premium |
| `users.quota_balance` | Current balance; atomically debited on each AI generation |
| `users.subscription_product_id` | Set by RC webhook on purchase/renewal, cleared on expiry/refund |

**Flow:**
1. RC webhook → middleware credits `quota_balance` + sets `subscription_product_id`
2. Flutter calls `GET /user/status` → returns `{ quotaBalance, isPremium, unlimited, gracePeriodUntil, subscriptionProductId, youtubeMinutes* }`
3. Flutter calls `POST /ai/generate` → middleware gates, debits, returns `QuotaSnapshot { balance, quotaCost, unlimited }`
4. Whitelisted users skip grant + gate + debit entirely

**Free grant:** `applyFreeGrantIfDue` resets balance to 3 monthly for free users whose `free_quota_reset_at` has passed. Called from both `/user/status` (so new users see their balance immediately) and `/ai/generate`.

### 11.4 Webhook reconciliation

`application/rc-webhook/apply-event.ts` is the pure event handler. It is called from:
- `POST /webhooks/revenuecat` (live delivery)
- `auth.middleware.ts` orphan replay — when a brand-new user signs in, any RC events that arrived for their `google_sub` before the user row existed are replayed asynchronously

`webhook_events` is the dedupe table (`UNIQUE(event_id)`). Watermark column ensures out-of-order delivery doesn't roll back a more recent state.

### 11.5 Paywall page

`PaywallPage` (`lib/features/paywall/presentation/pages/paywall_page.dart`):

- iOS-style design: `Color(0xFFF2F2F7)` grey background, white cards, `AppBar` matching dashboard/AI builder
- 3-card horizontal plan selector: Weekly | Annual (featured, "Save 78%") | Monthly
- Current plan card: grey + "CURRENT" label, non-tappable; purchase button disabled when selected == current
- "What's Included" card: dynamic first item shows quota count for the selected plan
- Footer: auto-renewal disclosure + Restore Purchases · Manage Subscription · Privacy Policy · Terms of Use (App Store guideline 3.1.2)
- Privacy / Terms open in-app via `SimpleWebViewPage`; Manage Subscription deep-links to `apps.apple.com/account/subscriptions`

---

## 12. AI Form Builder

### 12.1 Generation flow

1. User picks input type (text / PDF / YouTube / URLs / book)
2. **PDF/book only:** Flutter calls `POST /ai/pdf-page-count` → returns `{ pages, quotaCost, pagesPerQuota }`; client shows confirm dialog
3. Flutter calls `POST /ai/generate` with `Idempotency-Key` (UUIDv4) + `confirmedQuotaCost`
4. Middleware: whitelist short-circuit → premium gate (non-text input types) → free grant → quota gate → AI provider (Gemini) → debit → return form JSON + new `QuotaSnapshot`
5. Flutter receives `GeneratedForm` → tap "Create Form" → `forms.create` + `setPublishSettings` + `batchUpdate` (one `createItem` per question) → if `isQuiz: true` call `enableQuizMode(formId)` → navigate to `EditorPage`

### 12.2 Quiz auto-detection

The Gemini system prompt (v3) auto-detects quiz intent. No UI toggle. When `isQuiz: true`, `_buildGrading` attaches Forms-API `Grading` objects to gradeable questions (choice + short answer) and `enableQuizMode(formId)` is called after `batchUpdate`. SHORT_ANSWER feedback routes to `generalFeedback`; choice types use `whenRight` / `whenWrong` (per Forms API constraint).

### 12.3 Idempotency & retries

`Idempotency-Key` is a UUIDv4 generated once per logical attempt. The middleware caches `(user_id, idempotency_key) → ai_generation` and replays the cached 200 on any retry that uses the same key and the same canonical request body. Mismatched body → 409 `idempotency_conflict`; still-processing → 409 `idempotency_in_flight` for up to 2 minutes, then takeover.

The client reuses the same key on transient errors (503, network) and rotates only on:
- New `AiFormBuilderReady` (screen mount or post-paywall re-entry)
- Edit of the request body (prompt text or input type)

### 12.4 Middleware endpoints

| Endpoint | Auth | Purpose |
|---|---|---|
| `GET /user/status` | Google ID token | Returns `{ isPremium, quotaBalance, unlimited, gracePeriodUntil, subscriptionProductId, youtubeMinutesUsed, youtubeMinutesLimit, youtubeMinutesResetsAt }` |
| `POST /ai/generate` | Google ID token | Main generation endpoint; rate-limited, premium-gated, quota-gated, idempotent |
| `POST /ai/pdf-page-count` | Google ID token | Pre-flight quota cost for PDF/book |
| `POST /user/apple/check` | Google ID token | Returns `{ allowed, message? }` — refuses if Apple `original_transaction_id` is bound to another account |
| `POST /user/purchase/sync` | Google ID token | App-triggered RC reconcile via `RC_SECRET_API_KEY` |
| `POST /devices` / `DELETE /devices/:token` | Google ID token | FCM device token registration |
| `POST /watches` / `DELETE /watches/:watchId` | Google ID token, premium-only | Create / delete Google Forms watch |
| `POST /webhooks/revenuecat` | Bearer secret (static, `timingSafeEqual`) | RC event ingestion |
| `POST /webhooks/forms-watch` | Pub/Sub OIDC | Forms response → FCM fan-out |
| Admin `*` | `ADMIN_TOKEN` bearer | Quota Products, Whitelist, Kill Switches, Rate Limits, YouTube, Documents, Notifications |
| `GET /health`, `GET /metrics`, `GET /ping` | Health token / public | Observability |

> **Note on RC webhook auth.** RevenueCat sends the configured secret as a **plain bearer token** in the `Authorization` header (not as an HMAC of the body). The middleware does a constant-time string compare via `crypto.timingSafeEqual`. Earlier doc drafts described HMAC; that was wrong and never matched RC's actual delivery.

---

## 13. Database schema

Migrations live in `gfm_mw/migrations/` (sequence-numbered SQL, applied by `migrate.ts` on startup):

| File | Adds |
|---|---|
| `001_init.sql` | `users`, `ai_generations`, `webhook_events` |
| `002_server_config.sql` | `server_config` key/value table for `configService` |
| `003_youtube_minutes.sql` | `users.youtube_minutes_used`, `users.youtube_minutes_reset_at` |
| `004_quota_system.sql` | `quota_products`, `quota_transactions`, `quota_whitelist`; drops legacy tier counters; adds `quota_balance`, `free_quota_reset_at`, `subscription_product_id` to `users`; seeds dev whitelist |
| `005_rename_subscription_products.sql` | Renames product IDs from `gfm_weekly/monthly/yearly` → `GFM_Weekly_3.99` / `GFM_Monthly_4.99` / `GFM_Yearly_44.99`; re-points `quota_transactions` and `users.subscription_product_id` |
| `006_push_notifications.sql` | `device_tokens`, `form_watches`, `processed_pubsub_messages` |
| `007_event_watermark_and_dedupe.sql` | `users.event_watermark`; hardens out-of-order webhook handling |
| `008_apple_subscription_bindings.sql` | `apple_subscription_bindings (original_transaction_id PK, user_id, bound_at)`; backfills from `webhook_events` |

`docs/db/` is no longer maintained — the canonical migration source is `gfm_mw/migrations/`. The maintenance script `cleanup_expired_generations.sql` is now an inline scheduled job (or run manually); keep the file pinned in the deployment runbook.

---

## 14. Known API limitations

| Limitation | Handling |
|---|---|
| `FileUploadQuestion` cannot be created / edited via API | In-app WebView to Forms web editor |
| `imageItem` cannot be updated after creation | Delete + recreate |
| `documentTitle` cannot be changed via `batchUpdate` | Use `DriveApi.files.update` |
| Limit-one-response, shuffle, allow-edits, custom confirmation | Apps Script (extended settings) |
| Forms watches expire after 7 days | No auto-renewal — user re-toggles |
| `drive.file` scope — only lists app-created forms | Imported forms tracked in `gfm_data.json` appdata file |
| No offline support | Online-only for MVP |

---

## 15. Build & release

### Android
- `google-services.json` in `android/app/`
- `applicationId`: `com.app.formmanager`
- Core library desugaring enabled (required by `flutter_local_notifications`)
- Release signing: TODO (still on debug keystore at time of writing)

### iOS
- `GoogleService-Info.plist` in `ios/Runner/`
- Bundle ID: `com.rashed.gfm`
- `NSPhotoLibraryUsageDescription` in `Info.plist`
- `aps-environment: development` — switch to `production` before App Store submission
- `UIBackgroundModes: fetch, remote-notification`
- `GIDServerClientID` set to the web OAuth client ID

### Middleware
- Build: `docker build --target runtime -t gfm-middleware:latest .`
- Deploy: `./deploy.sh` from `gfm_mw/` — rsyncs source + `.env` to VPS, rebuilds, restarts Docker Compose
- Domain: `gfm.robi-dev.tech` (Hostinger DNS A record → VPS `177.7.51.7`)
- Nginx reverse-proxies `:80/:443` → app `:3002`; Let's Encrypt cert via certbot
- See `gfm_mw/docs/deployment-runbook.md` for first-time provisioning

### Pre-launch checklist
- [x] `forms.body` and `forms.responses.readonly` OAuth verification (sensitive scopes)
- [ ] Android release keystore + Play Console listing
- [ ] iOS production APNs (`aps-environment: production`) + App Store Connect listing
- [ ] Reviewer Google account added to `quota_whitelist` (so sandbox StoreKit purchases pass through webhook handling)
