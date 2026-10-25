import 'package:judgy/utils/currency_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurrencyFormatter', () {
    test('formats USD cents with grouping and two decimals', () {
      expect(CurrencyFormatter.usdFromCents(123456789), r'$1,234,567.89');
      expect(CurrencyFormatter.usdFromCents(-505), r'-$5.05');
    });

    test('formats YER as whole units', () {
      expect(CurrencyFormatter.yerFromUsdCents(10000, 540), 'YER 54,000');
    });

    test('parses grouped and decimal input', () {
      expect(CurrencyFormatter.parseAmount('1,250.75'), 1250.75);
      expect(CurrencyFormatter.parseAmount('12,5'), 12.5);
      expect(CurrencyFormatter.parseAmount('54,000'), 54000);
    });

    test('parses Arabic and Eastern Arabic numerals', () {
      expect(CurrencyFormatter.parseAmount('١٢٣٫٤٥'), 123.45);
      expect(CurrencyFormatter.parseAmount('۱۲۳'), 123);
    });

    test('rejects empty and non-finite input', () {
      expect(CurrencyFormatter.parseAmount(''), isNull);
      expect(CurrencyFormatter.parseAmount('NaN'), isNull);
      expect(CurrencyFormatter.parseAmount('Infinity'), isNull);
    });
  });
}
