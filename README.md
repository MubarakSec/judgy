# Judgy

A local-first Android money tracker built with Flutter. Record spending and income,
track a monthly spending budget, and view totals in USD or Yemeni riyals (YER).

## Daily use

- Filter the list to all, spent, or received transactions. Search titles, notes,
  categories, and displayed amounts. Sort by date, amount, or name; date order
  groups entries by day. The period summary stays complete while filtering the list.
- Filter by day, week, month, or a custom date range. Insights and recurring
  templates are in the top-bar overflow menu.
- Edit, duplicate, annotate, and undo deleted transactions. Each entry has its own
  currency; changing the display currency does not change saved amounts.
- Use **Use again** shortcuts in the home screen or notification sheet. They
  prefill the amount, currency, category, and name for review. Pin any transaction
  from its menu to keep it at the front of quick add.
- A basic entry needs a name and amount. Date and note stay under **Date and note**;
  the keyboard's Done action saves a valid entry.
- Mark an entry as **Spent** or **Received**. The home card shows both flows and
  the net amount; income does not use the spending budget.
- Set monthly category budgets in Settings. Insights shows the amount left or over
  each limit; category limits count current-month spending and ignore income.
- Insights compares spending and income across the last six calendar months. Tap
  a month for exact spent, received, and net totals; empty months stay visible.
- Save recurring spending or income templates, edit them, and apply each once per
  month, or enable auto-apply for due templates.
  Days 29–31 clamp to month end. Auto-apply checks on launch, resume, and enabling;
  it applies the current month, without backfilling missed months.
- On Android, tapping the persistent Quick add notification opens the entry sheet
  over the current app. Saving or dismissing it returns to that app. Settings →
  Quick add can turn the notification off.

## Storage, privacy, and recovery

- Records use integer USD cents and retain original entered currency/rate metadata.
- SQLite transactions commit expenses, recurring markers, and settings together.
  Existing version-2 preferences and older records migrate after validation.
- Unreadable/unsupported state is preserved and writes are blocked until a valid
  restore or explicit reset. Imports validate all rows and duplicate IDs first.
- Settings → Backup & restore exports portable JSON/CSV files through Android's
  share sheet, restores selected files with a replacement preview, and offers
  clipboard options. CSV retains notes and escapes spreadsheet formula-like text.
- A recovery copy is saved before an import replaces data. Seven daily snapshots
  are kept privately on the device, one on the first write with expenses each day.
  Export a backup outside the app for protection from uninstall or device loss.
- Optional device unlock covers the entire app, including open sheets, after
  backgrounding. Biometrics or device credentials can unlock it. Imported backups
  preserve the current device-lock setting.
- Expense records are not uploaded by Judgy. Android cloud backup is disabled.
  Local SQLite, snapshots, and exports are not application-encrypted.

## Development

```sh
flutter pub get
flutter analyze --no-pub
flutter test --no-pub --concurrency=1
flutter run
```

Tests cover imports, failed writes, SQLite migration and
transaction rollback, recurring concurrency/month-end rules, device-lock loading,
notification navigation, and compact/large-text interactions. The offline model
biometrics, file/share pickers, and notification behavior still require a real phone.

## Release signing

Copy `android/key.properties.example` to the ignored `android/key.properties` and
configure your private keystore. Release packaging requires signing credentials;
it does not fall back to debug signing. Do not commit keys or passwords. Local
device testing uses the gitignored debug-keystore configuration; replace it with a
private release keystore before distributing the app.
