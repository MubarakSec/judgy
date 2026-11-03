import 'expense.dart';

class MonthlyCashFlow {
  const MonthlyCashFlow({
    required this.month,
    required this.spentCents,
    required this.receivedCents,
  });

  final DateTime month;
  final int spentCents;
  final int receivedCents;
  int get netCents => receivedCents - spentCents;
  bool get isEmpty => spentCents == 0 && receivedCents == 0;
}

abstract final class CashFlowHistory {
  static List<MonthlyCashFlow> calculate({
    required Iterable<Expense> expenses,
    required DateTime now,
    int months = 6,
  }) {
    if (months < 1 || months > 24) {
      throw RangeError.range(months, 1, 24, 'months');
    }
    final first = DateTime(now.year, now.month - months + 1);
    final spent = List<int>.filled(months, 0);
    final received = List<int>.filled(months, 0);
    for (final expense in expenses) {
      if (expense.date.isAfter(now)) continue;
      final index =
          (expense.date.year - first.year) * 12 +
          expense.date.month -
          first.month;
      if (index < 0 || index >= months) continue;
      if (expense.isIncome) {
        received[index] += expense.amountCents;
      } else {
        spent[index] += expense.amountCents;
      }
    }
    return List.unmodifiable(
      List.generate(
        months,
        (index) => MonthlyCashFlow(
          month: DateTime(first.year, first.month + index),
          spentCents: spent[index],
          receivedCents: received[index],
        ),
      ),
    );
  }
}
