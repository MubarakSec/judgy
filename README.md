# Judgy

Judgy is a local-first Flutter expense tracker for recording everyday spending,
checking a monthly budget, and viewing totals in USD or YER. Its playful voice
adds accountability without requiring an account or a network connection.

## Features

- Add categorized expenses and filter them by day, week, or month.
- Track current-month spending against a configurable monthly budget.
- Display totals in USD or YER with a user-managed exchange rate.
- Keep expense data on the device using versioned local persistence.
- Recover accidental deletions with Undo.

## Privacy

Judgy does not send expense data to a server. Expense details and settings are
stored locally on the device. Android cloud backup is disabled for the app.

## Development

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

The app targets Android and iOS. A real-device pass is recommended for bottom
sheet safe areas, keyboard behavior, large text, and accessibility semantics.
