import 'package:judgy/models/recurring_expense.dart';
import 'package:judgy/providers/expense_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime(2026, 7, 12, 12);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('applies a due recurring expense once per month', () async {
    final provider = ExpenseProvider(clock: () => now);
    await provider.initialized;
    await provider.addRecurring(
      RecurringExpense(
        id: 'rent',
        title: 'Rent',
        amountCents: 100000,
        category: 'Other',
        dayOfMonth: 1,
      ),
    );

    expect(await provider.applyRecurring('rent'), isTrue);
    expect(provider.expenses, hasLength(1));
    expect(await provider.applyRecurring('rent'), isFalse);
    expect(provider.expenses, hasLength(1));
  });

  test('older recurring templates decode as spending', () {
    final item = RecurringExpense.fromMap({
      'id': 'rent',
      'title': 'Rent',
      'amountCents': 10000,
      'category': 'Home',
      'dayOfMonth': 1,
    });
    expect(item.type, 'expense');
    expect(item.isIncome, isFalse);
    expect(
      () => RecurringExpense.fromMap({...item.toMap(), 'type': 'transfer'}),
      throwsFormatException,
    );
  });

  test(
    'recurring income adds to received money without spending budget',
    () async {
      final provider = ExpenseProvider(clock: () => now);
      await provider.initialized;
      expect(
        await provider.addRecurring(
          const RecurringExpense(
            id: 'salary',
            title: 'Salary',
            amountCents: 200000,
            category: 'Salary',
            dayOfMonth: 1,
            type: 'income',
          ),
        ),
        isTrue,
      );
      expect(await provider.applyRecurring('salary'), isTrue);
      expect(provider.expenses.single.isIncome, isTrue);
      expect(provider.monthlyIncomeCents, 200000);
      expect(provider.monthlySpentCents, 0);
      expect(await provider.applyRecurring('salary'), isFalse);
      expect(provider.expenses, hasLength(1));
    },
  );

  test(
    'editing a due template preserves its monthly application marker',
    () async {
      final provider = ExpenseProvider(clock: () => now);
      await provider.initialized;
      await provider.setAutoApplyRecurring(true);
      await provider.addRecurring(
        const RecurringExpense(
          id: 'pay',
          title: 'Pay',
          amountCents: 10000,
          category: 'Income',
          dayOfMonth: 1,
          type: 'income',
        ),
      );
      expect(provider.expenses, hasLength(1));
      expect(
        await provider.updateRecurring(
          const RecurringExpense(
            id: 'pay',
            title: 'Pay revised',
            amountCents: 12000,
            category: 'Salary',
            dayOfMonth: 1,
            type: 'income',
          ),
        ),
        isTrue,
      );
      expect(provider.expenses, hasLength(1));
      expect(provider.recurringExpenses.single.lastApplied, isNotNull);
      expect(provider.recurringExpenses.single.amountCents, 12000);
      expect(await provider.reconcileRecurring(), isTrue);
      expect(provider.expenses, hasLength(1));
    },
  );
}
