import 'package:final_project/models/expense.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = DateTime(2026, 7, 12, 10, 30);

  group('Expense', () {
    test('migrates a legacy double amount to exact cents', () {
      final expense = Expense.fromMap({
        'id': 'legacy-1',
        'title': 'Coffee',
        'amount': 12.34,
        'date': date.toIso8601String(),
        'category': 'Coffee',
      });

      expect(expense.amountCents, 1234);
      expect(expense.amount, 12.34);
    });

    test('preserves YER entry metadata and exact USD cents', () {
      final expense = Expense.fromEnteredAmount(
        id: 'yer-1',
        title: 'Lunch',
        enteredAmount: 54000,
        currency: 'YER',
        exchangeRate: 540,
        date: date,
        category: 'Food',
      );

      expect(expense.amountCents, 10000);
      expect(expense.originalAmount, 54000);
      expect(expense.originalCurrency, 'YER');
      expect(expense.exchangeRateAtEntry, 540);
    });

    test('round-trips the versioned fields', () {
      final expense = Expense.fromEnteredAmount(
        id: 'round-trip',
        title: 'Groceries',
        enteredAmount: 48.75,
        currency: 'USD',
        exchangeRate: 540,
        date: date,
        category: 'Food',
      );

      final decoded = Expense.fromJson(expense.toJson());
      expect(decoded.amountCents, expense.amountCents);
      expect(decoded.originalAmountMinorUnits, 4875);
      expect(decoded.originalCurrency, 'USD');
      expect(decoded.date, date);
    });

    test('rejects empty titles and non-finite amounts', () {
      expect(
        () => Expense(
          id: 'invalid-title',
          title: '   ',
          amountCents: 100,
          date: date,
          category: 'Other',
        ),
        throwsArgumentError,
      );
      expect(
        () => Expense.fromEnteredAmount(
          id: 'invalid-amount',
          title: 'Invalid',
          enteredAmount: double.infinity,
          currency: 'USD',
          exchangeRate: 540,
          date: date,
          category: 'Other',
        ),
        throwsArgumentError,
      );
    });
  });
}
