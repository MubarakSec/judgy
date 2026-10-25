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
}
