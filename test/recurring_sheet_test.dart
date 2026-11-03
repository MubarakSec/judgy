import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:judgy/providers/expense_provider.dart';
import 'package:judgy/screens/recurring_sheet.dart';
import 'package:judgy/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'support/memory_repository.dart';

void main() {
  testWidgets('create and edit recurring income from the sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = ExpenseProvider(
      repository: MemoryRepository(),
      clock: () => DateTime(2026, 7, 12, 12),
    );
    await provider.initialized;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: RecurringSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add recurring transaction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Received').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Source'),
      'Salary',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '100');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(provider.recurringExpenses.single.isIncome, isTrue);
    expect(provider.recurringExpenses.single.category, 'Income');

    await tester.tap(find.byTooltip('Apply this month'));
    await tester.pumpAndSettle();
    expect(provider.monthlyIncomeCents, 10000);
    expect(provider.monthlySpentCents, 0);

    await provider.updateSettings(541.23, provider.monthlyBudget);
    await provider.toggleCurrency();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit Salary'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Source'),
      'Wages',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(provider.recurringExpenses.single.title, 'Wages');
    expect(provider.recurringExpenses.single.amountCents, 10000);
    expect(provider.expenses, hasLength(1));
  });
}
