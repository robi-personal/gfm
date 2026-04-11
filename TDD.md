# Technical Design Document
## GFM — Mobile Google Forms Companion

**Version:** 1.0 (MVP)
**Last updated:** 2026-04-11

---

## 1. Tech Stack

| Layer | Technology |
|---|---|
| Client framework | Flutter (stable channel), Dart 3.x |
| State management | `flutter_bloc` / Cubit |
| Google APIs | `package:googleapis ^16.0.0` (forms/v1, drive/v3) |
| Authentication | `package:google_sign_in ^6.x`, `package:googleapis_auth` |
| Dependency injection | `get_it` + `injectable` |
| Serialization | `freezed` + `json_serializable` (manual sealed classes for Forms API discriminated unions) |
| Local storage | `drift` (SQLite), `flutter_secure_storage` |
| Sharing | `share_plus` |
| Web view | `webview_flutter` |
| Image picking | `image_picker` |
| HTTP | Provided by `googleapis_auth` — no hand-rolled REST |
| Analytics | `firebase_analytics ^11.x` |
| Crash reporting | `firebase_crashlytics ^4.x` |

---

## 2. Project Structure

```
lib/
  main.dart                        Firebase init, Crashlytics hooks, DI setup
  app.dart                         MaterialApp, FirebaseAnalyticsObserver, AuthGate
  firebase_options.dart            Auto-generated Firebase platform config

  core/
    api/
      forms_client.dart            Lazy singleton wrapping FormsApi
      drive_client.dart            Lazy singleton wrapping DriveApi + uploadImage()
      concurrency.dart             runBatchUpdate() + isRevisionMismatch()
    auth/
      google_auth_datasource.dart  GoogleSignIn + _GoogleAuthClient (OAuth header injection)
    di/
      injection.dart               get_it registrations for all features
    error/
      failure.dart                 Sealed Failure hierarchy
    models/
      form_doc.dart
      item.dart
      item_content.dart            Sealed union: 6 variants
      question.dart
      question_kind.dart           Sealed union: 8 variants
      choice_option.dart           freezed
      form_image.dart              freezed
      form_settings.dart           freezed
      form_response.dart
      enums.dart
    services/
      analytics_service.dart       Static helpers for Analytics + Crashlytics
    usecases/
      usecase.dart                 UseCase<T,P> base + NoParams
    widgets/
      error_modal.dart             The only place errors are shown
      skeleton_bone.dart           Shimmer building block

  features/
    sign_in/                       Auth feature (clean arch)
    dashboard/                     Form list feature (clean arch)
    editor/                        Form editor feature (clean arch)
    responses/                     Responses viewer
    preview/                       Full-screen webview
```

---

## 3. Architecture

### 3.1 Clean Architecture (per feature)

```
Presentation  →  Domain  →  Data
(Cubit/Pages)    (UseCases/  (DataSources/
                  Entities/   RepositoryImpls)
                  Repositories)
```

Applied to: `sign_in`, `dashboard`, `editor`. Responses and preview are simpler (single-layer).

### 3.2 State Management

Each feature has one Cubit. State is an immutable sealed class:

```
EditorLoading
EditorLoaded(form, pending, isSaving, conflictPending, saveFailed, ...)
EditorError(message, kind)
```

`BlocSelector` and `buildWhen` guards prevent unnecessary rebuilds throughout the editor.

### 3.3 Dependency Injection

`get_it` with manual registrations in `injection.dart`. All singletons are lazy. Cubits are registered as factories (new instance per screen push). DI is initialized before `runApp`.

---

## 4. Authentication

### 4.1 OAuth Scopes

```
https://www.googleapis.com/auth/drive.file
https://www.googleapis.com/auth/forms.body
https://www.googleapis.com/auth/forms.responses.readonly
```

- `drive.file` — non-sensitive. Restricts Drive access to files the app created. Covers image upload flow.
- `forms.body` — sensitive. Required for Google OAuth verification before public launch.
- `forms.responses.readonly` — sensitive. Required for Google OAuth verification before public launch.

### 4.2 Auth Client

`_GoogleAuthClient extends http.BaseClient` intercepts every HTTP request and injects the `Authorization: Bearer <token>` header. Token refresh is handled automatically by `google_sign_in`. This client is passed to both `FormsApi` and `DriveApi` constructors.

### 4.3 Session Management

After sign-in: `AnalyticsService.setUser(email)` + `FirebaseCrashlytics.setUserIdentifier(email)`.
After sign-out: both clients reset (force fresh auth client on next sign-in), user identity cleared.

---

## 5. Domain Models

### 5.1 Serialization Approach

The Forms API uses **key-presence dispatch** (e.g., a JSON object has either a `textQuestion` key or a `choiceQuestion` key, never both). This does not fit standard discriminated union patterns (no `type` field to switch on).

**Decision:** `QuestionKind` and `ItemContent` are hand-written sealed classes with manual `fromJson` / `toJson`. All other models use `freezed`.

### 5.2 Critical Serialization Quirk

`package:googleapis` `Form.toJson()` puts nested Dart objects directly in the map (not plain `Map<String, dynamic>`). `FormDoc.fromJson()` crashes on these. Fix applied in `EditorDataSource.getForm`:

```dart
final clean = jsonDecode(jsonEncode(apiForm.toJson())) as Map<String, dynamic>;
return FormDoc.fromJson(clean);
```

### 5.3 Null-stripping

`freezed` `toJson()` includes `null` fields. `package:googleapis` `fromJson` crashes on nulls. All API objects are passed through `removeNulls(map)` before `forms_api.Item.fromJson`.

---

## 6. API Write Pattern

### 6.1 batchUpdate Flow

Every form mutation goes through `EditorRepositoryImpl.batchUpdate`:

1. First attempt with `WriteControl.requiredRevisionId = _revisionId`
2. On revision mismatch (400 with `ABORTED`): fetch fresh revision, retry once
3. Second mismatch: `Left(RevisionMismatchFailure())` → cubit shows conflict modal
4. Non-revision 400: `Left(ServerFailure())` immediately — no retry (deterministic failure)
5. Network/5xx: exponential backoff 1s → 3s → 8s

### 6.2 Deferred Save Design

All changes accumulate in `PendingChanges` until the user taps Save:

| Change type | Storage |
|---|---|
| Title / description | Latest value (last write wins) |
| Add item | Ordered list of `PendingCreate` with temp IDs |
| Delete item | Set of real item IDs |
| Edit item content | Map of item ID → mutated Item (last write wins per item) |
| Reorder | Derived at flush time from final order vs `serverItemOrder` |

### 6.3 Save Flush Order

1. `updateFormInfo` (title/desc)
2. Creates — sequential; capture real server IDs from responses
3. Refresh revision + `serverItemOrder`
4. Deletes — batch in descending index order (avoids index shift)
5. Edits — batch all (real IDs substituted for temp IDs)
6. Moves — diff final local order vs simulated server order
7. `_silentRefresh` — replace local `FormDoc` with clean server state

### 6.4 Temp ID Substitution

`createItem` API calls return real server IDs. A `tempIdMap: Map<String, String>` maps `_pending_<ts>` → real ID. All subsequent edits and moves use this map before building API requests.

---

## 7. Drive Image Upload Flow

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
Android: No manifest permission needed (image_picker uses system photo picker on API 33+).

---

## 8. Error Architecture

### 8.1 Failure Hierarchy

```dart
sealed class Failure
  NetworkFailure
  AuthFailure(message)
  AuthCancelledFailure
  ServerFailure(message)
  NotFoundFailure
  PermissionFailure
  RevisionMismatchFailure
```

### 8.2 Error Surface Rules

| Surface | When |
|---|---|
| Save-status pill | Silent retry in progress |
| Inline banner | Ambient degraded state |
| `ErrorModal` | User-actionable failure needing acknowledgement |
| Full-screen error | Screen cannot render anything useful |

**No snackbars. No toasts.** `ErrorModal.show()` is the only way to display errors — no ad-hoc `showDialog` with error content.

---

## 9. Analytics Design

All calls go through `AnalyticsService` (static methods) — no raw Firebase calls scattered in the codebase.

| Event | Triggered in |
|---|---|
| `form_created` | `DashboardCubit.createForm()` on success |
| `form_opened` | `EditorCubit.loadForm()` on success |
| `form_saved` | `EditorCubit.save()` after `_silentRefresh` |
| `question_added` | `EditorCubit.addQuestion()` |
| `image_added` (+ `source: url\|gallery`) | `EditorCubit.addImageItem()` |
| `video_added` | `EditorCubit.addVideoItem()` |
| `responses_viewed` | Tab change listener (index == 1) |
| `csv_exported` | After `Share.shareXFiles` succeeds |
| Screen views | Automatic via `FirebaseAnalyticsObserver` |

**What is NOT logged:** form titles, question text, response content, answer data, OAuth tokens.

---

## 10. Known API Limitations

| Limitation | Handling |
|---|---|
| `FileUploadQuestion` cannot be created | Read-only in domain model; excluded from type picker |
| `imageItem` cannot be updated after creation | Delete + recreate to "edit" an image |
| `documentTitle` cannot be changed via `batchUpdate` | Use `DriveApi.files.update` |
| No offline support | Online-only for MVP |
| `drive.file` scope — only lists app-created forms | Documented in dashboard empty state |

---

## 11. Build & Release Notes

### Android
- `google-services` plugin: declared in `settings.gradle.kts`, applied in `app/build.gradle.kts`
- `com.google.firebase.crashlytics` plugin applied in `app/build.gradle.kts`
- `google-services.json` in `android/app/`
- Release signing: TODO (currently using debug keystore)
- `applicationId`: `com.application.gfm`

### iOS
- `GoogleService-Info.plist` in `ios/Runner/`
- `NSPhotoLibraryUsageDescription` added to `Info.plist`
- Bundle ID: `com.app.gfm`
- Release: requires provisioning profile + distribution certificate

### OAuth Verification (pre-launch requirement)
- `forms.body` and `forms.responses.readonly` are sensitive scopes requiring Google verification
- Requires: privacy policy URL, app homepage, demo video, scope justification
- Estimated review time: 3–5 business days
