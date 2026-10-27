# Judgy

A local-first Android expense tracker built with Flutter. Record everyday spending,
track a monthly budget, and view totals in USD or Yemeni riyals (YER).

## Daily use

- Search titles, notes, categories, and displayed amounts. Use the sort icon inside
  search to order by date, amount, or name.
- Filter by day, week, month, or a custom date range. Insights and recurring
  templates are in the top-bar overflow menu.
- Edit, duplicate, annotate, and undo deleted expenses. Each entry has its own
  currency; changing the display currency does not change saved amounts.
- Apply recurring templates once per month, or enable auto-apply for due templates.
  Days 29–31 clamp to month end. Auto-apply checks on launch, resume, and enabling;
  it applies the current month, without backfilling missed months.

## Voice entry

Tap the microphone in the expense name field. Recognition runs fully offline with
a bundled multilingual Whisper model and does not use the phone's speech service.
Choose **Arabic** (the default), **English**, or experimental **Auto detect** in the
voice options. Examples:

- `قهوة مئتين وخمسين ريال أمس`
- `coffee twenty five point five dollars yesterday`
- `وفاء زيادة ٢٠٠`

Review the transcript, amount, currency, date, and suggested category, then tap
**Use entry**. The form remains editable; **Save expense** commits it. Missing or
ambiguous amounts, mixed currencies, income, and refund/subtraction commands are
blocked instead of silently becoming positive expenses. Judgy currently records
spending, not income or balances owed by people. Number-word support covers common
Arabic/English forms and needs dialect testing; it is not unrestricted
natural-language understanding.

The model is `ggml-base-q5_1.bin` (about 57 MB, multilingual). It is not committed
to git; fetch it once with `tool/fetch_whisper_model.sh` before building. The app
copies the bundled model into private app storage on first use. Audio never leaves
the device, and no cloud AI service is used.

The base model is fast and compact, but its Arabic accuracy is limited — especially
for names, dialects, and short phrases. Auto language detection is also unreliable
on short clips, so Arabic is the default. A larger Whisper small model is the next
quality step; it needs a device test and a bigger bundled download.

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
tool/fetch_whisper_model.sh
flutter pub get
flutter analyze --no-pub
flutter test --no-pub --concurrency=1
flutter run
```

Tests cover voice parsing/lifecycle, imports, failed writes, SQLite migration and
transaction rollback, recurring concurrency/month-end rules, device-lock loading,
notification navigation, and compact/large-text interactions. The offline model
loader is exercised on a phone; microphone, biometrics, file/share pickers, and
notification behavior still require a real phone.

## Release signing

Copy `android/key.properties.example` to the ignored `android/key.properties` and
configure your private keystore. Release packaging requires signing credentials;
it does not fall back to debug signing. Do not commit keys or passwords. Local
device testing uses the gitignored debug-keystore configuration; replace it with a
private release keystore before distributing the app.
