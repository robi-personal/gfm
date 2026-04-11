# Feature Flow Document
## GFM — Mobile Google Forms Companion

**Version:** 1.0 (MVP)
**Last updated:** 2026-04-11

---

## 1. Authentication Flow

### 1.1 First Launch / Sign In
```
App launch
  → Firebase.initializeApp()
  → configureDependencies()
  → SignInCubit.checkAuth() (silent sign-in attempt)
      ├─ Success → AuthUser → AnalyticsService.setUser(email)
      │            → emit Authenticated → DashboardPage
      └─ Failure → emit Unauthenticated → SignInScreen
                     → User taps "Sign in with Google"
                     → GoogleSignIn.signIn() (interactive)
                         ├─ Success → AnalyticsService.setUser(email)
                         │            → emit Authenticated → DashboardPage
                         ├─ Cancelled → emit Unauthenticated (stay on screen)
                         └─ Error → emit SignInError → inline banner
```

### 1.2 Sign Out
```
User taps Sign Out
  → SignInCubit.signOut()
  → FormsClient.reset() + DriveClient.reset()
  → AnalyticsService.clearUser()
  → emit Unauthenticated → SignInScreen
```

---

## 2. Dashboard Flow

### 2.1 Load Forms
```
DashboardPage mounts
  → DashboardCubit.loadForms()
  → emit DashboardLoading → shimmer skeleton shown
  → DriveApi.files.list(mimeType=form, trashed=false, orderBy=modifiedTime desc)
      ├─ Success → emit DashboardLoaded(forms) → form list rendered
      └─ Failure → emit DashboardError → full-screen error + Retry button
```

### 2.2 Search
```
User types in search bar (debounced)
  → DashboardCubit.search(query)
  → DriveApi.files.list(... and name contains '<query>')
  → emit DashboardLoaded(filtered) or DashboardLoaded([]) → search empty state
```

### 2.3 Create Form
```
User taps FAB "New form"
  → Name dialog (optional — defaults to "Untitled form")
  → DashboardCubit.createForm(title)
  → FAB shows spinner
  → FormsApi.forms.create(info: title)
  → FormsApi.forms.batchUpdate(createItem: default short-answer question)
  → FormsApi.forms.setPublishSettings(isPublished: true, isAcceptingResponses: true)
  → AnalyticsService.logFormCreated()
  → emit DashboardLoaded(nav: CreateNavigation(formId, formName))
  → Navigator.push → EditorPage(formId)
```

### 2.4 Open Form
```
User taps form card
  → Navigator.push → EditorPage(formId, formName)
```

### 2.5 Delete Form
```
User taps delete in overflow menu
  → Confirmation dialog
  → DashboardCubit.deleteForm(formId)
  → DriveApi.files.update(fileId, File(trashed: true))
  → Optimistic removal from list
      └─ Failure → ErrorModal + roll back (re-insert in list)
```

---

## 3. Editor Flow

### 3.1 Load Form
```
EditorPage mounts
  → EditorCubit.loadForm(formId)
  → emit EditorLoading → shimmer skeleton shown
  → FormsApi.forms.get(formId)
  → jsonDecode(jsonEncode(apiForm.toJson())) → FormDoc.fromJson()
  → cache revisionId + serverItemOrder
  → emit EditorLoaded(form)
  → AnalyticsService.logFormOpened()
```

### 3.2 Edit Title / Description
```
User types in title or description field
  → 600ms debounce
  → EditorCubit.updateTitleDesc(title, desc)
  → PendingChanges.titleDesc = (title, desc)
  → emit EditorLoaded (isDirty = true) → Save button appears
```

### 3.3 Add Question
```
User taps "+" (Add question) in bottom bar
  → EditorCubit.addQuestion()
  → Create placeholder Item(tempId, TextQuestion)
  → Append to local items list
  → PendingChanges.creates += PendingCreate(tempId)
  → emit EditorLoaded (isDirty = true)
  → Auto-scroll to new item
  → Question edit sheet opens automatically
  → AnalyticsService.logQuestionAdded()
```

### 3.4 Edit Question
```
User taps question card
  → QuestionEditSheet slides up
  → User edits title / type / options / required
  → EditorCubit.updateItem(itemId, updatedItem)
  → PendingChanges.edits[itemId] = updatedItem
  → emit EditorLoaded (isDirty = true)

User changes question type
  → TypePickerSheet
  → EditorCubit.changeQuestionType(itemId, newKind)
  → _mergeOptions() ensures ≥1 option for choice types
  → PendingChanges.edits[itemId] = mergedItem
```

### 3.5 Delete Item
```
User taps delete button on card
  → EditorCubit.deleteItem(itemId)
  → Remove from local items list
  → If real ID: PendingChanges.deletes += itemId
  → If temp ID: remove from PendingChanges.creates
  → emit EditorLoaded
```

### 3.6 Reorder Items
```
User long-presses item card → drag begins (ReorderableDelayedDragStartListener)
  → User drops at new position
  → EditorCubit.moveItem(oldIndex, newIndex)
  → Reorder local items list
  → emit EditorLoaded (isDirty = true if order differs from serverItemOrder)
```

### 3.7 Save
```
User taps Save button
  → EditorCubit.save()
  → emit EditorLoaded(isSaving: true) → save pill shows "Saving…"

  Step 1: updateFormInfo (if titleDesc pending)
  Step 2: Creates — sequential
    → For each PendingCreate:
        → _toApiItemForCreate() (strips itemId/questionId)
        → FormsApi.batchUpdate(createItem at index)
        → Capture real server ID → tempIdMap[tempId] = realId
  Step 3: Refresh revision + serverItemOrder
  Step 4: Deletes (descending index order)
    → FormsApi.batchUpdate(deleteItem × N)
  Step 5: Edits (batch)
    → Substitute temp IDs with real IDs from tempIdMap
    → removeNulls() → forms_api.Item.fromJson()
    → FormsApi.batchUpdate(updateItem × N)
  Step 6: Moves
    → Diff final local order vs simulated server order
    → FormsApi.batchUpdate(moveItem × N)
  Step 7: _silentRefresh → replace FormDoc with clean server state
  → AnalyticsService.logFormSaved()
  → emit EditorLoaded(isSaving: false, isDirty: false)

  On revision mismatch:
    → Fetch fresh revision → retry once
    → Second mismatch → emit conflictPending: true → conflict modal
      ├─ "Keep mine" → force retry with new revisionId
      └─ "Load latest" → _silentRefresh, discard pending

  On other failure:
    → emit snapshot.copyWith(isSaving: false, saveFailed: true)
    → ErrorModal shown
```

---

## 4. Media Insert Flows

### 4.1 Add Image — URL Path
```
User taps image button in bottom bar
  → showImageUrlDialog()
  → User pastes URL in text field
  → Live preview loads via Image.network()
  → User taps "Add"
  → EditorCubit.addImageItem(url)
  → AnalyticsService.logImageAdded(source: 'url')
```

### 4.2 Add Image — Gallery Path
```
User taps image button in bottom bar
  → showImageUrlDialog()
  → User taps "Pick from Gallery"
  → image_picker.pickImage(gallery, quality: 85)
  → Dialog shows "Uploading…" spinner
  → DriveClient.uploadImage(bytes, mimeType)
      → DriveApi.files.create(metadata, uploadMedia)
      → DriveApi.permissions.create(anyone/reader, fileId)
      → return 'https://drive.google.com/uc?id=$fileId&export=view'
  → Dialog auto-dismisses with URL
  → EditorCubit.addImageItem(driveUrl)
  → AnalyticsService.logImageAdded(source: 'gallery')

  On upload failure:
      → Dialog shows error text "Upload failed. Try again."
      → Spinner stops, button re-enabled
```

### 4.3 Add YouTube Video
```
User taps video button in bottom bar
  → VideoSearchDialog opens
  → User types search query
  → YouTube Data API search
  → Results list shown with thumbnails
  → User taps result
  → EditorCubit.addVideoItem(videoId, title)
  → AnalyticsService.logVideoAdded()
```

---

## 5. Sections & Branching Flow

### 5.1 Add Section
```
User taps "Add section" in bottom bar
  → EditorCubit.addSection()
  → Create placeholder Item(tempId, PageBreakItemContent)
  → PendingChanges.creates += PendingCreate(tempId)
```

### 5.2 Configure Branching
```
User edits a Radio or Dropdown question
  → QuestionEditSheet shows "Go to…" dropdown per option
    (only visible when form has ≥1 PageBreakItem)
  → User selects: Next section / specific section / Restart / Submit
  → EditorCubit.updateItem() with goToSectionId or goToAction on ChoiceOption
```

---

## 6. Quiz Mode Flow

### 6.1 Enable Quiz Mode
```
User taps "Make this a quiz" in Settings tab
  → EditorCubit.updateSettings(isQuiz: true)
  → FormsApi.batchUpdate(updateSettings)
  → Quiz grading UI revealed on each question card
```

### 6.2 Edit Answer Key
```
User taps "Answer key" on a question card (quiz mode only)
  → QuestionEditSheet shows point value + correct answers editor
  → EditorCubit.updateItem() with Grading block
  → PendingChanges.edits[itemId] = item with grading
```

### 6.3 Disable Quiz Mode
```
User toggles quiz off
  → Warning modal: "Disabling quiz mode will delete all point values and answer keys."
  → Confirm → EditorCubit.updateSettings(isQuiz: false)
```

---

## 7. Responses Flow

### 7.1 View Responses
```
User taps Responses tab in editor
  → Tab change listener → AnalyticsService.logResponsesViewed()
  → ResponsesCubit.loadResponses(formId)
  → FormsApi.forms.responses.list(formId, pageSize: 100)
  → Follow nextPageToken until exhausted
  → emit ResponsesLoaded(responses, items)

Summary tab:
  → Per-question aggregates rendered:
      ChoiceQuestion → bar chart (count per option)
      TextQuestion → text preview list
      ScaleQuestion / RatingQuestion → numeric average

Individual tab:
  → Paginated list, sorted newest-first
  → Tap → ResponseDetailScreen (question-by-question answers)
```

### 7.2 CSV Export
```
User taps "Export responses as CSV" in Settings tab
  → Load all responses (paginated)
  → Build CSV:
      Header: Timestamp, Email (if collected), <question titles in order>
      Rows: one per response
  → Write to temporary file
  → Share.shareXFiles([XFile(path, mimeType: text/csv)])
  → AnalyticsService.logCsvExported()
```

---

## 8. Preview & Share Flow

```
User taps Preview button
  → PreviewScreen pushes
  → WebViewWidget loads form.responderUri
  → Full-screen, no editor chrome

User taps Share button
  → Share.share(form.responderUri, subject: form.info.title)
  → OS share sheet opens
```

---

## 9. Error Flow (Save Path)

```
save() → batchUpdate fails
  │
  ├─ RevisionMismatch (1st time)
  │    → Silent: fetch new revision, retry
  │
  ├─ RevisionMismatch (2nd time)
  │    → emit conflictPending: true
  │    → ConflictModal: "Keep mine" / "Load latest"
  │
  ├─ Network / 5xx
  │    → Backoff: 1s → 3s → 8s
  │    → Pill: "Retrying…"
  │    → All 3 exhausted → ErrorModal: "Couldn't save." / Retry / Discard
  │
  └─ 400 (non-revision)
       → Immediate → ErrorModal: "Something went wrong."
       → Roll back to lastKnownGood state
```

---

## 10. Privacy Data Flow Summary

```
User's device
  ↕ OAuth 2.0 (HTTPS)
Google APIs (Forms + Drive)
  ↕ No data leaves this boundary except:
Firebase Analytics   ← event names + screen names only (no content)
Firebase Crashlytics ← stack traces + user email hash (no form content)
```

**Data that never leaves the device to third parties:**
- Form titles and descriptions
- Question text
- Response content
- Respondent information
- Any personally identifiable student data

---

## 11. Privacy Policy Key Points
*(Input for generating the full Privacy Policy)*

**App name:** GFM — Google Forms Manager
**Target users:** Teachers, administrative staff, and students at educational institutions
**Data controller:** The individual user (forms and responses live in their own Google account)

**Data collected by the app:**
| Data | Purpose | Stored where |
|---|---|---|
| Google account email | Authentication, user identity in crash reports | Google / Firebase (hashed) |
| OAuth access token | API calls to Google Forms and Drive | Device memory only (never persisted to disk by the app) |
| Form structure and content | Displayed and edited by the user | User's Google Drive only |
| Form responses | Displayed to form owner | Google Forms servers only |
| Uploaded images | Inserted into forms | User's Google Drive |
| App events (anonymized) | Product analytics | Firebase Analytics |
| Crash reports | Bug detection | Firebase Crashlytics |

**Data NOT collected:**
- Passwords
- Location
- Contacts
- Device identifiers beyond what Firebase SDK automatically collects
- Response content or student answers (never sent to analytics)

**Third-party services used:**
- Google Sign-In (authentication)
- Google Forms API (form management)
- Google Drive API (file storage, image hosting)
- Firebase Analytics (anonymized usage analytics)
- Firebase Crashlytics (crash reporting)

**Educational institution notes:**
- GFM is a form-creation tool for educators and staff; it is not a student-facing app
- Student data (form responses) is accessed read-only by the form owner via official Google APIs
- GFM does not process, store, or transmit student data on its own servers
- Institutions using Google Workspace for Education should ensure their Workspace agreement covers API-based access to Forms data
- FERPA compliance obligations remain with the institution's Google Workspace administrator

**User rights:**
- Users can revoke app access at any time via Google Account → Security → Third-party apps
- Revoking access does not delete forms or responses (they remain in Google Drive/Forms)
- To delete data: delete forms from Google Drive; this is outside the scope of GFM

**Contact:** *(add institution/developer contact email here)*
**Governing law:** *(add jurisdiction here)*
