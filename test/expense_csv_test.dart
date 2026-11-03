import 'package:flutter_test/flutter_test.dart';
import 'package:judgy/models/expense.dart';
import 'package:judgy/utils/expense_csv.dart';

void main() {
  test('round-trips expenses through CSV', () {
    final expense = Expense(
      id: 'csv-1',
      title: 'Coffee, large',
      amountCents: 450,
      date: DateTime(2026, 7, 12, 9),
      category: 'Coffee',
    );

    final csv = ExpenseCsv.encode([expense.toMap()]);
    final rows = ExpenseCsv.decode(csv);
    expect(rows, hasLength(1));
    final restored = Expense.fromMap(rows.first);
    expect(restored.id, expense.id);
    expect(restored.title, expense.title);
    expect(restored.amountCents, expense.amountCents);
  });

  test('keeps income type and reads old CSV rows as spending', () {
    final income = Expense(
      id: 'pay',
      title: 'Pay',
      amountCents: 2500,
      date: DateTime(2026, 7, 12),
      category: 'Salary',
      type: 'income',
    );
    final restored = Expense.fromMap(
      ExpenseCsv.decode(ExpenseCsv.encode([income.toMap()])).single,
    );
    expect(restored.isIncome, isTrue);
    final old = ExpenseCsv.decode(
      'id,title,amountCents,date,category\nold,Lunch,500,2026-07-12T12:00:00.000,Food\n',
    );
    expect(Expense.fromMap(old.single).isIncome, isFalse);
  });
}
