# Tasks — WebView Form Import

## Overview

Replace the manual URL/ID paste dialog with a Google Forms WebView browser.
User opens a persistent WebView showing `forms.google.com`, signs in once (session
persists until uninstall), taps any form, and it is automatically imported into the app.

Navigation interception detects when the WebView navigates to a form edit/view URL,
extracts the form ID, calls the existing `importForm` use case, and closes the sheet.

---

## T1 — `ImportFormWebViewPage` screen — `sonnet`

**File:** `lib/features/dashboard/presentation/pages/import_form_webview_page.dart` (new)

A full-screen page wrapping `webview_flutter`'s `WebViewWidget`.

**Constructor:** `const ImportFormWebViewPage({super.key})`

**Initial URL:** `https://forms.google.com`

**WebView setup:**
- `WebViewController` with `JavaScriptMode.unrestricted`
- `PlatformNavigationDelegate` with `onNavigationRequest`:
  - Intercept any URL matching `RegExp(r'/forms/d/([a-zA-Z0-9_-]{20,})')`
  - Extract the form ID from group 1
  - Call `Navigator.of(context).pop(formId)` — returns the ID to the caller
  - Return `NavigationDecision.prevent` to block the navigation
  - All other URLs: `NavigationDecision.navigate`
- `onPageStarted` / `onPageFinished`: drive a `LinearProgressIndicator` in the AppBar

**AppBar:**
- Title: `'Import Form'`
- Purple back button (same style as editor)
- Thin `LinearProgressIndicator` below the title row, visible only while loading

**Bottom hint bar:**
- Persistent small bar at the bottom: `'Tap any form to import it'` in gray text
- Same frosted/white card style as the rest of the app

---

## T2 — Wire into dashboard — `sonnet`

**File:** `lib/features/dashboard/presentation/pages/dashboard_page.dart`

Replace `showImportFormDialog` calls with the new WebView flow.

**Changes:**
- In the FAB `Import Form` action and the drawer `Import Form` item: instead of calling
  `showImportFormDialog(context, cubit)`, push `ImportFormWebViewPage` and await the result.
- If the result is a non-null `String` (form ID), call `cubit.importForm(result)` and show
  an `ErrorModal` on failure (same error handling as the old dialog).
- Delete `showImportFormDialog` and `_parseFormId` — no longer needed.
- Keep the rest of import/remove logic unchanged.
