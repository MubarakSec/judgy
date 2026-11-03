import 'package:flutter_test/flutter_test.dart';
import 'package:judgy/models/expense.dart';
import 'package:judgy/models/transaction_browser.dart';

void main() {
  Expense item(
    String id,
    String title,
    int cents,
    DateTime date, {
    String type = 'expense',
    String? note,
  }) => Expense(
    id: id,
    title: title,
    amountCents: cents,
    date: date,
    category: type == 'income' ? 'Salary' : 'Food',
    note: note,
    type: type,
  );

  final source = [
    item('lunch', 'Lunch', 1500, DateTime(2026, 11, 3, 12)),
    item('pay', 'Pay', 50000, DateTime(2026, 11, 3, 9), type: 'income'),
    item('coffee', 'Coffee', 300, DateTime(2026, 11, 2), note: 'with friends'),
  ];

  TransactionBrowseResult browse({
    TransactionKind kind = TransactionKind.all,
    TransactionSort sort = TransactionSort.newest,
    String query = '',
  }) => TransactionBrowser.browse(
    source: source,
    kind: kind,
    sort: sort,
    query: query,
    isUsd: true,
    exchangeRate: 540,
  );

  test('filters spending and income before sorting', () {
    expect(browse(kind: TransactionKind.spent).entries.map((e) => e.id), [
      'lunch',
      'coffee',
    ]);
    expect(browse(kind: TransactionKind.received).entries.map((e) => e.id), [
      'pay',
    ]);
  });

  test('search checks title, category, note, and display amount', () {
    expect(browse(query: 'friends').entries.single.id, 'coffee');
    expect(browse(query: 'salary').entries.single.id, 'pay');
    expect(browse(query: r'$15.00').entries.single.id, 'lunch');
    expect(
      browse(kind: TransactionKind.received, query: 'lunch').entries,
      isEmpty,
    );
  });

  test('newest sort groups by calendar day', () {
    final result = browse();
    expect(result.rows, hasLength(5));
    expect((result.rows.first as TransactionDayRow).count, 2);
    expect((result.rows[1] as TransactionEntryRow).entry.id, 'lunch');
    expect((result.rows[3] as TransactionDayRow).date, DateTime(2026, 11, 2));
  });

  test('amount and name sorts do not insert date headings', () {
    final amount = browse(sort: TransactionSort.highestAmount);
    expect(amount.entries.map((e) => e.id), ['pay', 'lunch', 'coffee']);
    expect(amount.rows.whereType<TransactionDayRow>(), isEmpty);
    final name = browse(sort: TransactionSort.name);
    expect(name.entries.map((e) => e.id), ['coffee', 'lunch', 'pay']);
    expect(name.rows.whereType<TransactionDayRow>(), isEmpty);
  });
}
