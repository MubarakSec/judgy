import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:judgy/models/expense.dart';
import 'package:judgy/models/expense_state.dart';
import 'package:judgy/providers/expense_provider.dart';

import 'support/memory_repository.dart';

void main() {
  final now = DateTime(2026, 11, 3, 12);

  Expense entry(String id, int cents, DateTime date, {bool income = false}) =>
      Expense(
        id: id,
        title: id,
        amountCents: cents,
        date: date,
        category: 'Food',
        type: income ? 'income' : 'expense',
      );

  test('category budget uses current-month spending only', () async {
    final repo = MemoryRepository();
    final provider = ExpenseProvider(repository: repo, clock: () => now);
    await provider.initialized;
    expect(await provider.setCategoryBudget('Food', 10000), isTrue);
    await provider.addExpense(entry('lunch', 6000, now));
    await provider.addExpense(entry('old', 9000, DateTime(2026, 10, 31)));
    await provider.addExpense(entry('future', 2000, DateTime(2026, 11, 4)));
    await provider.addExpense(entry('refund', 3000, now, income: true));
    expect(provider.categoryTotals['Food'], 6000);
    expect(provider.categoryBudgetCents['Food'], 10000);
    expect(provider.monthlyIncomeCents, 3000);

    final reloaded = ExpenseProvider(repository: repo, clock: () => now);
    await reloaded.initialized;
    expect(reloaded.categoryBudgetCents['Food'], 10000);
    expect(await reloaded.setCategoryBudget('Food', 0), isFalse);
    expect(reloaded.categoryBudgetCents['Food'], 10000);
    expect(await reloaded.setCategoryBudget('Food', null), isTrue);
    expect(reloaded.categoryBudgetCents, isEmpty);
  });

  test('older backups load and malformed category budgets are rejected', () {
    final state = ExpenseState.decode(const ExpenseState().encode());
    final legacy = Map<String, dynamic>.from(jsonDecode(state.encode()) as Map);
    legacy.remove('categoryBudgetCents');
    expect(
      ExpenseState.decode(jsonEncode(legacy)).categoryBudgetCents,
      isEmpty,
    );

    legacy['categoryBudgetCents'] = {'Food': -1};
    expect(
      () => ExpenseState.decode(jsonEncode(legacy)),
      throwsFormatException,
    );
    legacy['categoryBudgetCents'] = {'': 100};
    expect(
      () => ExpenseState.decode(jsonEncode(legacy)),
      throwsFormatException,
    );
    legacy['categoryBudgetCents'] = {'Food': '100'};
    expect(
      () => ExpenseState.decode(jsonEncode(legacy)),
      throwsFormatException,
    );
  });
}
