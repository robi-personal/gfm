# Tasks — iPad Adaptive Layout

## Overview

Add iPad-responsive layouts throughout the app. Mobile layouts are unchanged; tablet layouts
activate when `shortestSide >= 600`. Four discrete tasks.

---

## T1 — Breakpoint utility — `sonnet`

**File:** `lib/core/utils/layout.dart` (new)

```dart
bool isTablet(BuildContext context) =>
    MediaQuery.of(context).size.shortestSide >= 600;
```

Single function, imported wherever the adaptive branches are needed.

---

## T2 — Dashboard — persistent sidebar + 2-column grid — `sonnet`

**File:** `lib/features/dashboard/presentation/pages/dashboard_page.dart`

**Sidebar (replaces hamburger drawer on iPad):**
- Wrap the existing `Scaffold` body in a `LayoutBuilder` / `isTablet` check.
- On tablet: `Row` → permanent left sidebar (same content as `_buildDrawer`) + `Expanded` right content. Hide the hamburger `IconButton` in the AppBar. `Drawer` not provided to the `Scaffold` on tablet.
- On phone: no change — hamburger + `Drawer` exactly as today.
- Sidebar width: 280px (matches current `Drawer` width).

**2-column form grid:**
- The current `ListView.builder` for form entries becomes a `GridView.builder` with `crossAxisCount: isTablet ? 2 : 1` and `childAspectRatio: 4.5` (wide cards, not square thumbnails).
- Grid and list use the same `_FormCard` widget — no card changes needed.

---

## T3 — Editor — `NavigationRail` instead of top tab bar — `sonnet`

**File:** `lib/features/editor/presentation/pages/editor_page.dart`

On phone: `_SegmentedTabBar` stays at top, `TabBarView` below — no change.

On tablet:
- Remove `_SegmentedTabBar` from the `Column`.
- Wrap the `Scaffold` body in a `Row`:
  - Left: `NavigationRail` (width ~72px) with three destinations — Questions / Responses / Settings — using the same icons and labels as the current tab bar.
  - Right: `Expanded` wrapping the existing `TabBarView`.
- The `TabController` is shared — tapping a rail destination calls `_tabController.animateTo(index)`.
- `NavigationRail` `selectedIndex` stays in sync via a listener on `_tabController`.

---

## T4 — Template picker — 3-column grid on tablet — `sonnet`

**File:** `lib/features/dashboard/presentation/pages/template_picker_page.dart`

- The existing `GridView` `crossAxisCount: 2` becomes `crossAxisCount: isTablet(context) ? 3 : 2`.
- One-line change.
