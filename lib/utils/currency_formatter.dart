class CurrencyFormatter {
  const CurrencyFormatter._();

  static String normalizeDigits(String value) => _normalizeDigits(value);

  static String usdFromCents(int cents, {bool includeSign = true}) {
    final negative = cents < 0;
    final absolute = cents.abs();
    final whole = absolute ~/ 100;
    final fraction = (absolute % 100).toString().padLeft(2, '0');
    final value = '${_groupDigits(whole)}.$fraction';
    final prefix = includeSign ? r'$' : '';
    return '${negative ? '-' : ''}$prefix$value';
  }

  static String yerFromUsdCents(
    int usdCents,
    double exchangeRate, {
    bool includeCode = true,
  }) {
    final yer = (usdCents / 100 * exchangeRate).round();
    return yerAmount(yer, includeCode: includeCode);
  }

  static String yerAmount(int amount, {bool includeCode = true}) {
    final negative = amount < 0;
    final value = _groupDigits(amount.abs());
    final prefix = includeCode ? 'YER ' : '';
    return '${negative ? '-' : ''}$prefix$value';
  }

  static String displayFromUsdCents({
    required int usdCents,
    required bool isUsd,
    required double exchangeRate,
  }) {
    return isUsd
        ? usdFromCents(usdCents)
        : yerFromUsdCents(usdCents, exchangeRate);
  }

  static String originalAmount({
    required int minorUnits,
    required String currency,
  }) {
    final normalizedCurrency = currency.toUpperCase();
    if (normalizedCurrency == 'USD') return usdFromCents(minorUnits);
    if (normalizedCurrency == 'YER' && minorUnits % 100 == 0) {
      return yerAmount(minorUnits ~/ 100);
    }

    final negative = minorUnits < 0;
    final absolute = minorUnits.abs();
    final whole = absolute ~/ 100;
    final fraction = (absolute % 100).toString().padLeft(2, '0');
    return '${negative ? '-' : ''}$normalizedCurrency '
        '${_groupDigits(whole)}.$fraction';
  }

  static double? parseAmount(String raw) {
    var normalized = _normalizeDigits(raw.trim()).replaceAll(' ', '');
    if (normalized.isEmpty) return null;

    final hasDot = normalized.contains('.');
    final hasComma = normalized.contains(',');
    if (hasDot && hasComma) {
      normalized = normalized.replaceAll(',', '');
    } else if (hasComma) {
      final commaIndex = normalized.lastIndexOf(',');
      final decimals = normalized.length - commaIndex - 1;
      normalized = decimals == 1 || decimals == 2
          ? normalized.replaceFirst(',', '.')
          : normalized.replaceAll(',', '');
    }

    final value = double.tryParse(normalized);
    return value != null && value.isFinite ? value : null;
  }

  static String _groupDigits(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[index]);
    }
    return buffer.toString();
  }

  static String _normalizeDigits(String value) {
    const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
    const easternArabic = '۰۱۲۳۴۵۶۷۸۹';
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final character = String.fromCharCode(rune);
      final arabicIndex = arabicIndic.indexOf(character);
      final easternIndex = easternArabic.indexOf(character);
      if (character == '٫') {
        buffer.write('.');
      } else if (character == '٬') {
        buffer.write(',');
      } else if (character == '−') {
        buffer.write('-');
      } else if (arabicIndex >= 0) {
        buffer.write(arabicIndex);
      } else if (easternIndex >= 0) {
        buffer.write(easternIndex);
      } else {
        buffer.write(character);
      }
    }
    return buffer.toString();
  }
}
