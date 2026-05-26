# Session Context — Mobile Google Forms Companion (GFM)

Read this file at the start of every session before touching any code. v1 has shipped — this is the slim "what you need to know to safely work on v2+" file. Historical session logs were removed during the 2026-05-27 consolidation; full architectural and operational detail lives in `docs/`.

---

## Status

**v1 shipped.** All MVP features are complete and in the app stores (or queued for review). Codebase, middleware, and docs are aligned as of 2026-05-27.

Remaining work for next phase:
- UI polish — thumb-zone audit, spacing, typography refinements
- Post-launch ops: store metrics dashboards, crash-rate alerts
- Anything that surfaces from real user feedback once v1 is live

The doc set is canonical for behavior and APIs — read `docs/PRD.md` / `docs/TDD.md` / `docs/api-contract.md` for current truth. This file is the project's tribal knowledge — things that wouldn't be obvious from reading code.

---

## Critical architecture decisions

### State management

- `flutter_bloc` Cubits (NOT Riverpod — codebase is fully on Bloc; do not migrate).
- The editor splits state across **three tab cubits** (`QuestionsCubit`, `ResponsesCubit`, `SettingsCubit`) plus `ExtendedSettingsCubit` for the Apps Script bridge, wired via `MultiBlocProvider` in `EditorPage`.
- `BlocSelector` and `buildWhen` guards prevent unnecessary rebuilds — particularly important on save-status changes that previously rebuilt the entire scaffold.

### API write pattern (Forms `batchUpdate`)

Every form mutation goes through `EditorRepositoryImpl.batchUpdate`:
1. First attempt with `WriteControl.requiredRevisionId`.
2. On revision mismatch (400 `ABORTED`): fetch fresh revision, retry once.
3. Second mismatch: returns `Left(RevisionMismatchFailure())` → cubit emits `conflictPending: true`.
4. Non-revision 400: returns `Left(ServerFailure())` immediately (no retry — deterministic failure).
5. Network/5xx: exponential backoff 1s → 3s → 8s.

### Serialization quirks (important)

- `googleapis` `Form.toJson()` puts nested Dart objects directly in the map (not plain Maps). Fix: always `jsonDecode(jsonEncode(apiForm.toJson()))` before passing to `FormDoc.fromJson()`. Applied in `EditorDataSource.getForm`.
- `freezed` `toJson()` includes `null` fields; `googleapis` `fromJson` crashes on nulls. All API request bodies pass through `removeNulls(map)` before `forms_api.Item.fromJson`.
- Google sometimes returns `null` for `value` on `ChoiceOption` and `CorrectAnswer` entries. Both `.g.dart` files coerce `json['value'] as String? ?? ''`.

### Domain models

- `QuestionKind` and `ItemContent` are **hand-written sealed classes** with manual `fromJson` / `toJson` — the Forms API uses key-presence dispatch, not a `type` discriminator.
- All other models use `freezed`.

### Drive image upload flow

`image_picker` → bytes → `DriveClient.uploadImage()` → Drive multipart upload → set `anyone/reader` permission → `https://drive.google.com/uc?id={fileId}&export=view` → used as `sourceUri` in `ImageItemContent`. Scope: `drive.file` (already in use).

### File upload questions

Forms API cannot create or edit `fileUploadItem`. App shells out to the Google Forms web editor inside `EditFormWebViewPage` (in-app WebView) for both create and edit. Existing file-upload questions are read-only in the editor UI.

### Premium gating rule (do not break)

- Always check `/user/status` (`GetUserStatus`) for feature access, **never** `SubscriptionService.isPremium()` (RC SDK client-side). Server is the source of truth — it respects the whitelist override and the actual quota balance.
- `Purchases.logIn` must use the Google `sub` (from `GoogleSignInAccount.id`), not email. Otherwise the RC webhook resolves the wrong user and quota credits silently land on the floor.

### Deferred Save design

All changes accumulate in `PendingChanges` until the user taps Save:

| Change type | Storage |
|---|---|
| Title / description | Latest value (last write wins) |
| Add item | Ordered list of `PendingCreate` with temp IDs |
| Delete item | Set of real item IDs |
| Edit item content | Map of item ID → mutated Item (last write wins per item) |
| Reorder | Derived at flush time from final order vs `serverItemOrder` |

Flush order on Save:
1. `updateFormInfo` (title/desc)
2. Creates — sequential; capture real server IDs from responses
3. Refresh revision + `serverItemOrder`
4. Deletes — batch in descending index order
5. Edits — batch (real IDs substituted for temp IDs from `tempIdMap`)
6. Moves — diff final local order vs simulated server order
7. `_silentRefresh` — replace local `FormDoc` with clean server state

### Auth scopes

```
drive.file
forms.body
forms.responses.readonly
```

`drive.file` covers both reading/listing app-created Drive files and the image upload flow. No Sheets API scope — CSV export only.

---

## Bugs fixed — do not reintroduce

Numbered for stable reference in commits.

1. **`addQuestion` refresh**: was calling `loadForm` (emits `EditorLoading` → destroys widget tree). Use `_silentRefresh`.
2. **Reorder index bug**: header in `SliverToBoxAdapter`, items in `SliverReorderableList` with clean 0-based indices.
3. **Save-status rebuilds**: every `saveStatus` change rebuilt entire Scaffold. Use `BlocSelector` + `buildWhen` guards.
4. **`ChoiceQuestion` empty options**: type switch from non-choice type sent `options: []` → API 400. `_mergeOptions` always seeds `[ChoiceOption(value: 'Option 1')]`.
5. **`googleapis` `Form.toJson()` nested objects**: always `jsonDecode(jsonEncode(...))` before `FormDoc.fromJson()`.
6. **`removeNulls` for `googleapis.Item.fromJson`**: freezed includes null fields; `googleapis` crashes on nulls.
7. **Scroll triggers reorder**: use `ReorderableDelayedDragStartListener`, not `ReorderableDragStartListener`.
8. **`createItem` temp IDs**: Forms API rejects output-only `itemId` / `questionId`. `_toApiItemForCreate` strips both before API call.
9. **`updateItem` temp IDs**: substitute real server ID from `tempIdMap` before sending edits.
10. **400 errors retried for 12s**: throw immediately on non-revision 400; only network/5xx hit the backoff loop.
11. **Pure reorder not dirty**: `EditorLoaded.isDirty` compares current item order vs `serverItemOrder` in addition to checking `pending`.
12. **`ChoiceOption.value` / `CorrectAnswer.value` null crash**: Google returns null on some options. Both `.g.dart` files coerce `as String? ?? ''`.
13. **Cubit emit-after-close**: guard every `await` followed by `emit` with `if (isClosed) return`. Applies to `EditorCubit.loadForm/save/updateSettings`, `DashboardCubit.importForm`, and any future async cubit method.
14. **Template grid items not created**: `_stripIds` must remove `questionId` from all rows in `questionGroupItem.questions`, not just `questionItem.question`.
15. **RevenueCat `app_user_id` was email**: must be the Google ID-token `sub`. Set in `SignInCubit` → `_subscriptionService.identifyUser(user.googleId)`. Do NOT change to email.
16. **Stale grading on non-quiz forms**: `QuestionEditSheet._commit` must start `grading` as null, only build it when `widget.isQuiz` is true. Otherwise the Forms API rejects with `Invalid grading`.
17. **`echo "X='${VAR}'"` mangles JSON with `\n` in zsh**: `echo` interprets backslash escapes; private_key's `\n` becomes actual newlines. Use base64 encoding (codified in `fcm.service.ts`) or Python/Node to write the env value.
18. **iOS Simulator APNs unreliable**: even on iOS 16+ Apple Silicon, `getAPNSToken()` often returns null. Test push delivery on a real iOS device.
19. **`Stream.broadcast` drops events with no listener**: for terminated-app deep-links, buffer the tap data (`_pendingInitialTap` + `Stream.multi`) until the destination widget mounts.
20. **Pub/Sub topic permission lives at topic level, not subscription**: granting `Pub/Sub Publisher` to a subscription is a no-op for Forms watches.
21. **`pdf` package has no `FractionallySizedBox`**: use `Row` + `Expanded(flex: ...)` with integer percentages for proportional bars.
22. **`Printing.layoutPdf` doesn't resolve cleanly across foreground/background transitions**: clear "printing" loader state BEFORE calling `layoutPdf`.
23. **RC webhook auth is plain bearer, not HMAC**: `crypto.timingSafeEqual` of the `Authorization` header against `RC_WEBHOOK_SECRET`. HMAC computation against the body will always 401.
24. **Stale appdata file ID on account switch**: `DriveDataSource.reset()` must be called from `SignInCubit.signOut()` alongside `_driveClient.reset()` / `_formsClient.reset()`. Otherwise the next sign-in reads the previous user's `gfm_data.json` ID and either succeeds wrongly (same user) or 404/403s silently (different user).
25. **WebView cookies are independent of native Google Sign-In**: `WebViewSessionManager.syncWithUser(googleSub)` clears the WebView cookie jar on sub change. Keyed on `google_sub` (immutable), not email.
26. **iOS ID token audience**: `google_sign_in` on iOS issues tokens with the **iOS** client ID as audience, not the web client ID. `google-token-verifier.ts` must accept both. Do NOT remove `GOOGLE_IOS_CLIENT_ID` from `.env`.
27. **`deploy.sh` overwrites VPS `.env`**: always update local `.env` before deploying when rotating secrets, otherwise the VPS gets the stale value.

---

## What NOT to do

- Do NOT add snackbars/toasts — use `ErrorModal.show()` only.
- Do NOT call `loadForm` during editing — destroys the widget tree. Use `_silentRefresh`.
- Do NOT use `forms.create` with items — API rejects everything except `info`. Create blank, then `setPublishSettings`, then `batchUpdate`.
- Do NOT hand-roll REST calls for Google APIs — use `package:googleapis`.
- Do NOT skip `setPublishSettings` after create — forms are unpublished by default since March 31 2026.
- Do NOT use `identical()` for `FormDoc` equality on item changes — `copyWith` always creates a new list reference.
- Do NOT pass null-containing maps to `googleapis` `fromJson` — always `removeNulls` first.
- Do NOT attempt to create `FileUploadQuestion` via the API — it's read-only; use the WebView path.
- Do NOT check `SubscriptionService.isPremium()` (RC SDK) for feature gating — always use `/user/status`.
- Do NOT change `Purchases.logIn` to use email or anything other than the Google `sub`.
- Do NOT remove `_driveDataSource.reset()` from `SignInCubit.signOut()`.
- Do NOT skip the `WebViewSessionManager` sync on sign-in — leaks Drive content across account switches.

---

## Key files

```
lib/
  main.dart                          Firebase, RC.configure, DI, NotificationService.init, runApp
  app.dart                           MaterialApp + AnalyticsObserver + SignInCubit gate
  core/
    api/forms_client.dart            FormsApi wrapper, reset on sign-out
    api/drive_client.dart            DriveApi wrapper + uploadImage()
    api/apps_script_client.dart      Extended-settings bridge to user's Apps Script web app
    api/concurrency.dart             runBatchUpdate() + isRevisionMismatch()
    auth/google_auth_datasource.dart GoogleSignIn + _GoogleAuthClient (OAuth header injection)
    di/injection.dart                get_it registrations for everything
    error/failure.dart               Sealed Failure hierarchy
    services/webview_session_manager.dart  Clears WebView cookies on google_sub change
    theme/, design.dart              Design tokens (AppColors, AppTextStyles, AppShapes)
  features/
    sign_in/                         Clean arch — auth flow + post-sign-in init
    dashboard/                       Form list, drawer, templates, in-app Drive import WebView
    editor/                          Three-tab editor (questions / responses / settings),
                                     pdf_builders for response export, file-upload WebView
    ai_form_builder/                 HTTP to middleware, GeneratedForm → forms.create + batchUpdate
    paywall/                         RC SDK, purchase_activation_service (sync), Apple channel
    notifications/                   FCM init, device-token registration, deep-link buffer

gfm_mw/                              See docs/TDD.md §1.2 for full layout
```

---

## Critical gotchas (consolidated)

These are non-obvious traps. Each one wasted hours during v1 — keep them visible.

- **Forms watches expire after 7 days** with no app-side renewal. If a user re-enables an expired watch, a new one is created via `forms.watches.create` and the `(form_id, user_id)` row is upserted. Decision: most forms are short-term surveys; no auto-renewal scheduler.
- **forms.google.com no longer shows a forms list** — redirects straight to "create new form". The Drive import flow targets `https://drive.google.com/drive/u/0/search?q=type:form` instead.
- **`flutter_inappwebview`'s `NavigationType` is unreliable on iOS** (often `-1`). Don't depend on it to distinguish user taps from redirects. Use the injected document-level click handler instead.
- **WKWebView platform views leave a black artifact** during route exit if disposed mid-animation. Pattern: swap WebView for `CupertinoActivityIndicator`, wait 120ms, then `Navigator.pop`. Used in `ImportFormWebViewPage._popWithResult` and `SimpleWebViewPage`.
- **Forms web editor has fixed top chrome (`vDIOnd`, `MBLJ9d`, `KP7TGc`)** that must be hidden via injected CSS in `EditFormWebViewPage` — `MBLJ9d` is a 146px spacer that must be hidden alongside `vDIOnd`.
- **The "force-quit creates session-mismatch bug" worry was overblown** — changing the app's signed-in account requires (a) explicit sign-out → sign-in (caught by compare-on-sign-in), (b) reinstall (wipes WebView), or (c) removing the Google account from device Settings (rare). All three are covered by the existing `WebViewSessionManager.syncWithUser` check on every silent sign-in.
- **iOS keychain (used by `flutter_secure_storage`) persists across uninstall**. Harmless for our use (stale stored sub triggers one unnecessary clear on first launch of a fresh install) but worth knowing.
- **In-flight AI generation is fire-and-forget** when the user pops the AI builder. The server completes and caches against the idempotency key. If the user re-enters and submits the same prompt with the same key (retained by cubit if they don't dismiss), the server returns a cached 200 instantly.

---

## App identifiers + infra

- **iOS bundle ID:** `com.rashed.gfm` — APNs `aps-environment: development` (switch to `production` before App Store submission).
- **Android applicationId:** `com.app.formmanager`.
- **Middleware:** `https://gfm.robi-dev.tech` → VPS `root@177.7.51.7` (Hostinger).
- **RC app ID:** `appl_MkzXtKeEEhIYCwtQEgOdWquRCGK`. Entitlement: `GFMPremium`. Offering: `default`. Products: `GFM_Weekly_3.99`, `GFM_Monthly_4.99`, `GFM_Yearly_44.99`.
- **GCP:** project `form-manager-493310`, Pub/Sub topic `projects/form-manager-493310/topics/forms-responses`, push subscription → `https://gfm.robi-dev.tech/webhooks/forms-watch` with OIDC.
