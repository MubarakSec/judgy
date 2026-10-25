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
}
