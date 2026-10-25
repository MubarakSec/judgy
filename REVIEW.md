# Judgy Full Review

Personal-tool assessment: Judgy is already a solid local-first expense tracker.
The core money math, versioned persistence, corrupt-state protection, and
accessibility work are in good shape. The changes below focus on making it
safer and more useful day to day without turning it into a bloated app.

## Strengths

- Money is stored in integer cents, including original YER entry metadata.
- State is versioned and corrupt/unsupported state is not overwritten.
- Undo after delete is implemented well.
- Filtering, monthly budget math, and semantics are tested.
- Android cloud backup is disabled.
- Voice quick-add and persistent quick-add notification exist.

## Implemented in this review

- Reduced Gradle heap from 8 GB to 512 MB to respect low-RAM machines.
- Request Android notification permission before showing the quick-add notification.
- Replaced timestamp-based expense IDs with UUIDs.
- Added in-app search by title, category, and displayed amount.
- Added clipboard backup and restore in Settings.
- Kept `flutter analyze` and `flutter test` green.

## Recommended next (highest value for a personal tool)

### P0 - Harden

- Add a real release signing config using a local `key.properties` file; never commit keys.
- Encrypt local storage or move to SQLCipher/encrypted drift if the device is shared.
- Make writes atomic (write temp + rename) or move to SQLite to avoid partial JSON corruption.
- Add an automatic daily/weekly backup file in app documents plus a "last backup" timestamp.
- Handle Android 13+ notification permission denial gracefully and re-prompt from Settings.

### P1 - Make daily use easier

- Add recurring expenses (rent, subscriptions, salary) with one-tap confirm.
- Add CSV export/import and a monthly summary export for budgeting.
- Add category and date-range filters, plus "last 30 days" and "custom range".
- Add budget alerts when crossing 80%, 100%, and 120% of the monthly budget.
- Add spending insights: top categories, daily average, month-over-month change.
- Add a home-screen widget or quick-settings tile for one-tap expense entry.
- Let categories be renamed, reordered, and extended without code changes.
- Support multiple currencies beyond USD/YER, or at least a second "travel" currency.

### P2 - Quality and maintainability

- Introduce a repository interface and move persistence to drift/SQLite before adding search/export at scale.
- Add golden/widget tests for settings, editing, and voice parsing.
- Add crash-safe migration tests for future schema versions.
- Keep the notification channel and speech locale configurable instead of hardcoded.
- Add a light theme and respect system theme preference.

## Suggested first milestone

1. Release signing + backup file.
2. Recurring expenses + budget alerts.
3. SQLite/drift migration behind the repository interface.
4. CSV export and monthly summary.
