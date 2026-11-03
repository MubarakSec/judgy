import 'package:flutter_test/flutter_test.dart';
import 'package:judgy/models/cash_flow_history.dart';
import 'package:judgy/models/expense.dart';

void main() {
  Expense entry(String id, int cents, DateTime date, {bool income = false}) =>
      Expense(
        id: id,
        title: id,
        amountCents: cents,
        date: date,
        category: 'Other',
        type: income ? 'income' : 'expense',
      );

  test('six-month history crosses years and fills months without entries', () {
    final now = DateTime(2026, 2, 10, 12);
    final months = CashFlowHistory.calculate(
      now: now,
      expenses: [
        entry('sep', 100, DateTime(2025, 9, 1)),
        entry('dec', 200, DateTime(2025, 12, 31)),
        entry('feb', 300, DateTime(2026, 2, 1), income: true),
        entry('too-old', 400, DateTime(2025, 8, 31)),
        entry('future', 500, DateTime(2026, 2, 11)),
      ],
    );
    expect(months, hasLength(6));
    expect(months.first.month, DateTime(2025, 9));
    expect(months.first.spentCents, 100);
    expect(months[1].isEmpty, isTrue);
    expect(months[3].spentCents, 200);
    expect(months.last.month, DateTime(2026, 2));
    expect(months.last.receivedCents, 300);
    expect(months.last.netCents, 300);
  });

  test('income and spending share a month but net stays signed', () {
    final months = CashFlowHistory.calculate(
      now: DateTime(2026, 11, 3),
      expenses: [
        entry('spent', 5000, DateTime(2026, 11, 2)),
        entry('received', 3000, DateTime(2026, 11, 1), income: true),
      ],
    );
    expect(months.last.spentCents, 5000);
    expect(months.last.receivedCents, 3000);
    expect(months.last.netCents, -2000);
  });

  test('history length is bounded', () {
    expect(
      () => CashFlowHistory.calculate(
        now: DateTime(2026),
        expenses: const [],
        months: 0,
      ),
      throwsRangeError,
    );
  });
}
