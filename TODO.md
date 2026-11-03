# Judgy TODO

## Critical
- [x] Corrupt/unsupported saved state must not be overwritten; track load failure and block writes or back up raw JSON; add test.

## High
- [x] Centralize categories (label, icon, quotes) in one registry; remove duplicates.
- [x] Date picker + edit expense (backdated entries, edit flow).
- [x] Release identity: applicationId/package name, signing config; update README (Android-only).
- [x] Search, sort, duplicate, notes, and CSV/JSON backup.
- [x] Recurring expenses and budget alerts.
- [x] Biometric lock and haptic feedback.
- [x] Storage abstraction and transactional SQLite migration, with import recovery and daily snapshots.

## Medium
- [x] Exchange rate upper bound validation.
- [x] Fix TotalSpentCard progress-bar Semantics (inside ExcludeSemantics).
- [x] Remove unused compatibility code (displayTotal/displayBudget/totalSpentUSD) or wire up.
- [x] Add LICENSE, CI (flutter analyze + test), screenshots.

## Product (new)
- [x] Frequent transaction shortcuts and income tracking.
- [x] Quick-add from notification / always-on surface for fast entry.
- [ ] Keep personal tool efficient and low battery; avoid hardcoded values.

## Done
- [x] Install deps and toolchain; analyze/test green.
- [x] Render UI screenshots into gitignored `refrences/`.

## Upgrade validation
- [x] Search-integrated sorting and scrollable compact home layout.
- [x] Removed voice entry and the bundled speech model.
- [x] Import validation, atomic recurring application, reset protection, and CSV note preservation.
- [x] Device lock gates loading, sheets, dialogs, and quick-add navigation.
- [ ] Real Android device pass: unlock, file/share pickers, notifications, and entry form layout.
- [ ] Full Arabic UI localization, configurable category management, and a light theme.
