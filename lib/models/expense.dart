import 'dart:convert';

/// An immutable expense whose base USD value is stored exactly in cents.
///
/// [amount] remains available as a compatibility view for older UI code. New
/// call sites should prefer [amountCents] or [Expense.fromEnteredAmount].
class Expense {
  static const int _maxSafeJsonInteger = 9007199254740991;
  static const double _maxExchangeRate = 1000000.0;

  final String id;
  final String title;
  final int amountCents;
  final DateTime date;
  final String category;
  final String? note;

  /// The entered value in hundredths of [originalCurrency], when known.
  final int? originalAmountMinorUnits;

  /// The ISO-style currency code used when this expense was entered.
  final String? originalCurrency;

  /// The number of [originalCurrency] units per USD at entry time.
  final double? exchangeRateAtEntry;

  factory Expense({
    required String id,
    required String title,
    int? amountCents,
    double? amount,
    required DateTime date,
    required String category,
    String? note,
    int? originalAmountMinorUnits,
    String? originalCurrency,
    double? exchangeRateAtEntry,
  }) {
    if ((amountCents == null) == (amount == null)) {
      throw ArgumentError(
        'Provide exactly one of amountCents or the legacy amount value.',
      );
    }

    final validatedAmountCents = amountCents != null
        ? _validatePositiveInteger(amountCents, 'amountCents')
        : _usdDoubleToCents(amount!, 'amount');
    final validatedOriginalAmount = originalAmountMinorUnits == null
        ? null
        : _validatePositiveInteger(
            originalAmountMinorUnits,
            'originalAmountMinorUnits',
          );
    final validatedCurrency = originalCurrency == null
        ? null
        : _validateCurrency(originalCurrency);
    final validatedRate = exchangeRateAtEntry == null
        ? null
        : _validateExchangeRate(exchangeRateAtEntry, 'exchangeRateAtEntry');
    final validatedNote = note == null ? null : _validateNote(note);

    return Expense._(
      id: _validateText(id, 'id'),
      title: _validateText(title, 'title'),
      amountCents: validatedAmountCents,
      date: date,
      category: _validateText(category, 'category'),
      note: validatedNote,
      originalAmountMinorUnits: validatedOriginalAmount,
      originalCurrency: validatedCurrency,
      exchangeRateAtEntry: validatedRate,
    );
  }

  const Expense._({
    required this.id,
    required this.title,
    required this.amountCents,
    required this.date,
    required this.category,
    required this.note,
    required this.originalAmountMinorUnits,
    required this.originalCurrency,
    required this.exchangeRateAtEntry,
  });

  /// Creates an expense while retaining the amount and rate the user saw.
  factory Expense.fromEnteredAmount({
    required String id,
    required String title,
    required double enteredAmount,
    required String currency,
    required double exchangeRate,
    required DateTime date,
    required String category,
    String? note,
  }) {
    final normalizedCurrency = _validateCurrency(currency);
    final normalizedRate = _validateExchangeRate(
      exchangeRate,
      'exchangeRate',
    );
    final originalMinorUnits = _decimalDoubleToMinorUnits(
      enteredAmount,
      'enteredAmount',
    );
    final usdAmount = normalizedCurrency == 'USD'
        ? enteredAmount
        : enteredAmount / normalizedRate;

    return Expense(
      id: id,
      title: title,
      amountCents: _usdDoubleToCents(usdAmount, 'USD amount'),
      date: date,
      category: category,
      note: note,
      originalAmountMinorUnits: originalMinorUnits,
      originalCurrency: normalizedCurrency,
      exchangeRateAtEntry: normalizedRate,
    );
  }

  /// Compatibility view of [amountCents] as USD.
  double get amount => amountCents / 100;

  /// The entered amount as a decimal value, when its metadata is available.
  double? get originalAmount =>
      originalAmountMinorUnits == null ? null : originalAmountMinorUnits! / 100;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'amountCents': amountCents,
      'date': date.toIso8601String(),
      'category': category,
      if (note != null && note!.isNotEmpty) 'note': note,
      if (originalAmountMinorUnits != null)
        'originalAmountMinorUnits': originalAmountMinorUnits,
      if (originalCurrency != null) 'originalCurrency': originalCurrency,
      if (exchangeRateAtEntry != null)
        'exchangeRateAtEntry': exchangeRateAtEntry,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    final rawDate = map['date'];
    if (rawDate is! String) {
      throw const FormatException('Expense date must be a string.');
    }

    final amountCents = map.containsKey('amountCents')
        ? _parsePositiveInteger(map['amountCents'], 'amountCents')
        : _parseLegacyAmount(map['amount']);
    final rawOriginalAmount = map['originalAmountMinorUnits'];
    final rawCurrency = map['originalCurrency'];
    final rawRate = map['exchangeRateAtEntry'];

    return Expense(
      id: _parseString(map['id'], 'id'),
      title: _parseString(map['title'], 'title'),
      amountCents: amountCents,
      date: DateTime.parse(rawDate),
      category: _parseString(map['category'], 'category'),
      note: map['note'] is String ? (map['note'] as String).trim() : null,
      originalAmountMinorUnits: rawOriginalAmount == null
          ? null
          : _parsePositiveInteger(
              rawOriginalAmount,
              'originalAmountMinorUnits',
            ),
      originalCurrency: rawCurrency == null
          ? null
          : _parseString(rawCurrency, 'originalCurrency'),
      exchangeRateAtEntry: rawRate == null
          ? null
          : _parsePositiveFinite(rawRate, 'exchangeRateAtEntry'),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory Expense.fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Expense JSON must contain an object.');
    }
    return Expense.fromMap(Map<String, dynamic>.from(decoded));
  }

  static int _parseLegacyAmount(dynamic value) {
    if (value is! num) {
      throw const FormatException('Expense amount is missing or invalid.');
    }
    final amount = value.toDouble();
    if (!amount.isFinite || amount <= 0) {
      throw const FormatException(
        'Expense amount must be finite and positive.',
      );
    }
    return _usdDoubleToCents(amount, 'amount');
  }

  static int _parsePositiveInteger(dynamic value, String field) {
    if (value is! num || !value.isFinite || value <= 0) {
      throw FormatException('$field must be a positive integer.');
    }
    final asDouble = value.toDouble();
    if (asDouble != asDouble.truncateToDouble() ||
        asDouble > _maxSafeJsonInteger) {
      throw FormatException('$field must be a safe positive integer.');
    }
    return asDouble.toInt();
  }

  static double _parsePositiveFinite(dynamic value, String field) {
    if (value is! num) {
      throw FormatException('$field must be numeric.');
    }
    final result = value.toDouble();
    if (!result.isFinite || result <= 0) {
      throw FormatException('$field must be finite and positive.');
    }
    return result;
  }

  static String _parseString(dynamic value, String field) {
    if (value is! String) {
      throw FormatException('$field must be a string.');
    }
    return value;
  }

  static int _usdDoubleToCents(double amount, String field) {
    return _decimalDoubleToMinorUnits(amount, field);
  }

  static int _decimalDoubleToMinorUnits(double amount, String field) {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(amount, field, 'must be finite and positive');
    }
    final scaled = amount * 100;
    if (!scaled.isFinite || scaled > _maxSafeJsonInteger) {
      throw ArgumentError.value(amount, field, 'is too large to store safely');
    }
    final rounded = scaled.round();
    if (rounded <= 0) {
      throw ArgumentError.value(amount, field, 'is smaller than one cent');
    }
    return rounded;
  }

  static int _validatePositiveInteger(int value, String field) {
    if (value <= 0 || value > _maxSafeJsonInteger) {
      throw ArgumentError.value(
        value,
        field,
        'must be a safe positive integer',
      );
    }
    return value;
  }

  static double _validatePositiveFinite(double value, String field) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(value, field, 'must be finite and positive');
    }
    return value;
  }

  static double _validateExchangeRate(double value, String field) {
    final result = _validatePositiveFinite(value, field);
    if (result > _maxExchangeRate) {
      throw ArgumentError.value(
        value,
        field,
        'must not exceed $_maxExchangeRate',
      );
    }
    return result;
  }

  static String _validateCurrency(String value) {
    final normalized = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(normalized)) {
      throw ArgumentError.value(value, 'currency', 'must be a 3-letter code');
    }
    return normalized;
  }

  static String? _validateNote(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  static String _validateText(String value, String field) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, field, 'must not be empty');
    }
    return normalized;
  }
}
