import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:judgy/models/expense.dart';
import 'package:judgy/models/expense_state.dart';
import 'package:judgy/models/ledger_category.dart';
import 'package:judgy/models/recurring_expense.dart';
import 'package:judgy/providers/expense_provider.dart';

import 'support/memory_repository.dart';

void main() {
  test(
    'theme and categories survive reload; rename follows saved data',
    () async {
      final repository = MemoryRepository();
      Future<ExpenseProvider> open() async {
        final p = ExpenseProvider(
          repository: repository,
          clock: () => DateTime(2026, 11, 4),
        );
        await p.initialized;
        return p;
      }

      final p = await open();
      expect(await p.setThemeMode('light'), isTrue);
      expect(
        await p.addCategory(
          const LedgerCategory(
            label: 'Transit',
            type: 'expense',
            iconKey: 'transport',
          ),
        ),
        isTrue,
      );
      expect(
        await p.addExpense(
          Expense(
            id: 'fare',
            title: 'Bus',
            amountCents: 250,
            date: DateTime(2026, 11, 4),
            category: 'Transit',
          ),
        ),
        isTrue,
      );
      expect(await p.setCategoryBudget('Transit', 1000), isTrue);
      expect(
        await p.addRecurring(
          RecurringExpense(
            id: 'pass',
            title: 'Pass',
            amountCents: 500,
            category: 'Transit',
            dayOfMonth: 4,
          ),
        ),
        isTrue,
      );
      expect(
        await p.updateCategory(
          oldLabel: 'Transit',
          replacement: const LedgerCategory(
            label: 'Travel',
            type: 'expense',
            iconKey: 'travel',
          ),
        ),
        isTrue,
      );
      expect(p.expenses.single.category, 'Travel');
      expect(p.expenses.single.amountCents, 250);
      expect(p.recurringExpenses.single.category, 'Travel');
      expect(p.categoryBudgetCents['Travel'], 1000);
      expect(p.categoryBudgetCents.containsKey('Transit'), isFalse);
      expect(await p.removeCategory('Travel', 'expense'), isFalse);
      final reloaded = await open();
      expect(reloaded.themeMode, 'light');
      expect(
        reloaded
            .categoriesFor('expense')
            .any((e) => e.label == 'Travel' && e.iconKey == 'travel'),
        isTrue,
      );
      expect(reloaded.expenses.single.category, 'Travel');
      expect(
        await reloaded.addCategory(
          const LedgerCategory(label: 'Bonus', type: 'income', iconKey: 'gift'),
        ),
        isTrue,
      );
      expect(await reloaded.removeCategory('Bonus', 'income'), isTrue);
    },
  );

  test('old backup gains categories for custom transaction names', () {
    final old = ExpenseState(
      expenses: [
        Expense(
          id: 'x',
          title: 'Bus',
          amountCents: 200,
          date: DateTime(2026, 11, 4),
          category: 'Transit',
        ),
      ],
    ).toMap();
    old.remove('categories');
    old.remove('themeMode');
    final restored = ExpenseState.decode(jsonEncode(old));
    expect(restored.categories.any((e) => e.label == 'Transit'), isTrue);
    expect(restored.themeMode, 'dark');
  });
}
