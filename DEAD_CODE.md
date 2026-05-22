# Dead Code Report

> Generated: 2026-05-22  
> Scope: `lib/` (excluding generated files `*.g.dart`, `*.freezed.dart`)

---

## Unused Widget Classes

These classes are fully implemented and exported but are never instantiated anywhere in the codebase.

| File | Class | Notes |
|------|-------|-------|
| `lib/core/widgets/ds_buttons.dart:58` | `SecondaryButton` | Only a private `_SecondaryButton` in `error_modal.dart` exists — not the same class |
| `lib/core/widgets/ds_buttons.dart:104` | `TertiaryTextButton` | No instantiation found anywhere |
| `lib/core/widgets/ds_buttons.dart:130` | `DsIconButton` | No instantiation found anywhere |
| `lib/core/widgets/ds_stepper.dart:8` | `DsStepper` | Exported via `core/design.dart`, never used |
| `lib/core/widgets/ds_toggle.dart:4` | `DsToggle` | Exported via `core/design.dart`, never used |
| `lib/core/widgets/brand_mark.dart:11` | `BrandMark` | Exported via `core/design.dart`, never used |

All six are exported from `lib/core/design.dart` as part of the design system barrel, but no feature code references any of them.

---

## Notes

- `PrimaryButton` (`ds_buttons.dart:8`) **is** used — e.g. in `dashboard_dialogs.dart`.
- `isRevisionMismatch` (`core/api/concurrency.dart`) **is** used in `editor_repository_impl.dart`.
- `DsToggle` and `DsStepper` are complete, polished widgets — likely built in anticipation of future screens.
- `BrandMark` docstring says "used in nav bar and sign-in screen" but no current code references it (may have been removed during a refactor).
