# Judgy TODO

## Critical
- [x] Corrupt/unsupported saved state must not be overwritten; track load failure and block writes or back up raw JSON; add test.

## High
- [ ] Centralize categories (label, icon, quotes) in one registry; remove duplicates.
- [ ] Date picker + edit expense (backdated entries, edit flow).
- [ ] Release identity: applicationId/package name, signing config; update README (Android-only).
- [ ] Storage abstraction: repository interface + move from SharedPreferences to SQLite/drift (before search/export).

## Medium
- [ ] Exchange rate upper bound validation.
- [ ] Fix TotalSpentCard progress-bar Semantics (inside ExcludeSemantics).
- [ ] Remove unused compatibility code (displayTotal/displayBudget/totalSpentUSD) or wire up.
- [ ] Add LICENSE, CI (flutter analyze + test), screenshots.

## Product (new)
- [ ] Voice quick-add parsing Arabic commands ("زيادة"/"ناقص") and add expense.
- [ ] Quick-add from notification / always-on surface for fast entry.
- [ ] Keep personal tool efficient and low battery; avoid hardcoded values.

## Done
- [x] Install deps and toolchain; analyze/test green.
- [x] Render UI screenshots into gitignored `refrences/`.
