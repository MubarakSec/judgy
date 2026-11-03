import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:judgy/models/expense.dart';
import 'package:judgy/providers/expense_provider.dart';
import 'package:judgy/screens/insights_sheet.dart';
import 'package:judgy/screens/settings_sheet.dart';
import 'package:judgy/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'support/memory_repository.dart';

void main() {
  testWidgets('set a category limit and see remaining and over-budget states', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime(2026, 11, 3, 12);
    final provider = ExpenseProvider(
      repository: MemoryRepository(),
      clock: () => now,
    );
    await provider.initialized;
    Widget app(Widget sheet) => ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: sheet),
      ),
    );

    await tester.pumpWidget(app(const SettingsSheet()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Category budgets'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add category budget'));
    await tester.tap(find.text('Add category budget'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Monthly limit'),
      '25',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(provider.categoryBudgetCents['Coffee'], 2500);

    await tester.pumpWidget(app(const InsightsSheet()));
    await tester.pumpAndSettle();
    expect(find.text(r'$25.00 left of $25.00 limit'), findsOneWidget);
    await provider.addExpense(
      Expense(
        id: 'coffee',
        title: 'Coffee',
        amountCents: 3000,
        date: now,
        category: 'Coffee',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(r'$5.00 over $25.00 limit'), findsOneWidget);
  });
}
