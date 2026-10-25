import 'dart:convert';

import 'package:final_project/models/expense.dart';
import 'package:final_project/providers/expense_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime(2026, 7, 12, 12);

  Expense expense(String id, int cents, DateTime date) {
    return Expense(
      id: id,
      title: 'Expense $id',
      amountCents: cents,
      date: date,
      category: 'Other',
    );
  }

  Future<ExpenseProvider> createProvider() async {
    final provider = ExpenseProvider(clock: () => now);
    await provider.initialized;
    return provider;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('uses calendar periods and excludes future expenses', () async {
    final provider = await createProvider();
    await provider.addExpense(expense('today', 100, DateTime(2026, 7, 12, 9)));
    await provider.addExpense(expense('week', 200, DateTime(2026, 7, 6, 9)));
    await provider.addExpense(expense('month', 300, DateTime(2026, 7, 1, 9)));
    await provider.addExpense(expense('past', 400, DateTime(2026, 6, 30, 9)));
    await provider.addExpense(expense('future', 500, DateTime(2026, 7, 13, 9)));

    provider.setTimeFilter('Day');
    expect(provider.filteredExpenses.map((item) => item.id), ['today']);
    expect(provider.totalSpentCents, 100);

    provider.setTimeFilter('Week');
    expect(provider.filteredExpenses.map((item) => item.id), ['today', 'week']);

    provider.setTimeFilter('Month');
    expect(provider.filteredExpenses.map((item) => item.id), [
      'today',
      'week',
      'month',
    ]);
    expect(provider.monthlySpentCents, 600);
  });

  test('monthly budget progress does not change with list filter', () async {
    final provider = await createProvider();
    expect(await provider.updateSettings(540, 10), isTrue);
    await provider.addExpense(expense('today', 200, DateTime(2026, 7, 12, 9)));
    await provider.addExpense(expense('earlier', 300, DateTime(2026, 7, 1, 9)));

    provider.setTimeFilter('Day');
    expect(provider.totalSpentCents, 200);
    expect(provider.monthlySpentCents, 500);
    expect(provider.budgetProgress, 0.5);

    provider.setTimeFilter('Month');
    expect(provider.budgetProgress, 0.5);
    expect(provider.monthlyRemainingCents, 500);
  });

  test('persists one versioned state document and restores it', () async {
    final provider = await createProvider();
    await provider.updateSettings(600, 750);
    await provider.toggleCurrency();
    await provider.addExpense(expense('saved', 1234, now));

    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString('judgy_state_v2');
    expect(encoded, isNotNull);
    final state = jsonDecode(encoded!) as Map<String, dynamic>;
    expect(state['version'], 2);
    expect(state['monthlyBudgetCents'], 75000);

    final restored = await createProvider();
    expect(restored.isUSD, isFalse);
    expect(restored.exchangeRate, 600);
    expect(restored.expenses.single.amountCents, 1234);
  });

  test('migrates valid legacy rows and skips only damaged rows', () async {
    final valid = expense('valid', 250, now);
    SharedPreferences.setMockInitialValues({
      'isUSD': false,
      'exchangeRate': 550.0,
      'monthlyBudget': 600.0,
      'expenses': <String>[valid.toJson(), 'not json'],
    });

    final provider = await createProvider();
    expect(provider.expenses.map((item) => item.id), ['valid']);
    expect(provider.warningMessage, contains('One damaged expense'));
    expect(provider.isUSD, isFalse);
    expect(provider.monthlyBudgetCents, 60000);
  });

  test('remove and restore supports undo at the original position', () async {
    final provider = await createProvider();
    await provider.addExpense(
      expense('first', 100, now.subtract(const Duration(minutes: 1))),
    );
    await provider.addExpense(expense('second', 200, now));

    final removal = await provider.removeExpense('second');
    expect(removal, isNotNull);
    expect(provider.expenses.map((item) => item.id), ['first']);

    expect(await provider.restoreExpense(removal!), isTrue);
    expect(provider.expenses.map((item) => item.id), ['second', 'first']);
  });

  test('rejects unsafe settings without mutating current values', () async {
    final provider = await createProvider();
    final originalRate = provider.exchangeRate;
    final originalBudget = provider.monthlyBudgetCents;

    expect(await provider.updateSettings(0, 500), isFalse);
    expect(await provider.updateSettings(double.infinity, 500), isFalse);
    expect(await provider.updateSettings(540, -1), isFalse);
    expect(await provider.updateSettings(540, 1e20), isFalse);
    expect(provider.exchangeRate, originalRate);
    expect(provider.monthlyBudgetCents, originalBudget);
    expect(provider.errorMessage, isNotNull);
  });
}
