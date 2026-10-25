# Judgy upgrade review — 25 October 2026

The upgrade follows the initial source review. `git pull --ff-only` first advanced
main from `9f36798` to `e6adcce`; that upstream change already corrected the Android
namespace and enabled notification desugaring.

## Delivered

- Moved sort into the search field, added clear-search, grouped secondary actions,
  and made the home content scroll together for short screens and large text.
- Added a voice transcript/review step, installed-language selection, explicit
  entry currency, Arabic/English number words, today/yesterday, and category hints.
  Ambiguous amounts/currencies and unsupported income/refund commands are blocked.
- Kept speech callbacks in a persistent controller; handled errors, cancellation,
  initialization races, late results, and backgrounding. On-device mode checks
  native capability before listening; online recognition requires an explicit choice.
- Introduced a repository and a versioned state model. Production uses SQLite;
  existing preferences migrate only after complete validation. Record updates,
  settings, recurring markers, and import recovery are transactional.
- Validated imports before replacing anything. Missing lists, malformed records,
  duplicate IDs, empty CSV, and malformed quoting are rejected. A failed write
  leaves both the visible state and persistent state unchanged.
- Made recurring application atomic and idempotent per template/month; fixed
  short-month scheduling and validated recurring forms. Current-month due entries
  are reconciled on launch, resume, enabling auto-apply, and template creation.
- Preserved original money metadata when editing notes or titles. Duplicates use
  today's date. CSV keeps notes and escapes formula-like spreadsheet cells.
- Added file export/restore with replacement previews, pre-import recovery,
  and seven app-private daily snapshots. Reset persists an empty current state,
  clears legacy preference data in production, and removes recovery/snapshot copies.
- Added a lock gate around the Navigator, including sheets/dialogs, with settings
  loading protection and deferred notification navigation. The Android host now
  uses FlutterFragmentActivity and AppCompat themes. Device lock is preserved
  when importing backups.
- Added warm-app notification routing and a separate high-importance budget-alert
  channel. Notification failures cannot make a committed expense appear unsaved.
- Removed debug-signing fallback for releases and added a release-signing check.
- Narrowed expense-row subscriptions to currency changes and corrected insight
  comparisons to use the same elapsed period in the previous month.

## Validation

- `flutter analyze --no-pub`: **no issues found**.
- `flutter test --no-pub --concurrency=1`: **60 tests passed**.
- SQLite tests cover migration/reopening and an injected failure after row changes,
  verifying rollback of both the expense and recurring marker.
- Widget tests cover delayed lock settings, backgrounding with an unsaved sheet,
  deferred quick-add, search/sort, voice confirmation/currency, note-only edits,
  grouped settings, and a 360 × 640 screen with large text and keyboard insets.
- Screens were rendered locally for visual inspection; this caught a Material
  surface issue in the shared sheet and was followed by a regression test.
- No APK, Gradle build, emulator, or device integration test was run on the VPS.

## Practical limits and next work

Voice is deterministic entry assistance, not unrestricted natural-language AI.
Number words cover common Arabic/English forms; actual recognition and dialect
accuracy depend on the device and its language packs. Strict on-device recognition
requires Android 12+ and an available native on-device recognizer. Income,
refunds, and per-person balances require a separate product/data-model decision.

Native speech, offline language availability, biometrics/device credentials,
notification delivery, file selectors, sharing, and release signing still need a
real Android device and eventual build validation on a stronger runner.

SQLite and local snapshots are not application-encrypted, and local copies do
not protect against uninstall or device loss. Export outside the app for that.
The app still loads history into memory; database transactions improve safety,
while very large histories would benefit from paginated queries. Full Arabic UI
localization, configurable category management, and a light theme remain separate
product enhancements.
