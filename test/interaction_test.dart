import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:judgy/main.dart';
import 'package:judgy/models/expense.dart';
import 'package:judgy/models/transaction_browser.dart';
import 'package:judgy/providers/expense_provider.dart';
import 'package:judgy/widgets/expense_tile.dart';
import 'package:provider/provider.dart';

import 'support/memory_repository.dart';

void main() {
  final now = DateTime(2026, 10, 25, 12);
  void size(WidgetTester tester, {Size size = const Size(430, 932)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<ExpenseProvider> provider() async {
    final p = ExpenseProvider(repository: MemoryRepository(), clock: () => now);
    await p.initialized;
    return p;
  }

  testWidgets('sort is inside search and changes visible order', (
    tester,
  ) async {
    size(tester);
    final p = await provider();
    await p.addExpense(
      Expense(
        id: 'a',
        title: 'Cheap coffee',
        amountCents: 100,
        date: now,
        category: 'Coffee',
      ),
    );
    await p.addExpense(
      Expense(
        id: 'b',
        title: 'Large lunch',
        amountCents: 500,
        date: now.subtract(const Duration(hours: 1)),
        category: 'Food',
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: p, child: const JudgyApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sort by'), findsNothing);
    await tester.tap(find.byTooltip('Sort transactions'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('Highest amount'),
        matching: find.byType(CheckedPopupMenuItem<TransactionSort>),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .getTopLeft(
            find.descendant(
              of: find.byType(ExpenseTile),
              matching: find.text('Large lunch'),
            ),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.descendant(
                of: find.byType(ExpenseTile),
                matching: find.text('Cheap coffee'),
              ),
            )
            .dy,
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'coffee');
    await tester.pumpAndSettle();
    expect(find.text('Large lunch'), findsNothing);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(ExpenseTile),
        matching: find.text('Large lunch'),
      ),
      findsOneWidget,
    );
  });
  testWidgets('transaction type filter keeps search and summary separate', (
    tester,
  ) async {
    size(tester);
    final p = await provider();
    await p.addExpense(
      Expense(
        id: 'lunch',
        title: 'Lunch',
        amountCents: 1200,
        date: now,
        category: 'Food',
      ),
    );
    await p.addExpense(
      Expense(
        id: 'pay',
        title: 'Pay',
        amountCents: 30000,
        date: now,
        category: 'Salary',
        type: 'income',
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: p, child: const JudgyApp()),
    );
    await tester.pumpAndSettle();
    final receivedFilter = find.descendant(
      of: find.byType(SegmentedButton<TransactionKind>),
      matching: find.text('Received'),
    );
    await tester.ensureVisible(receivedFilter);
    await tester.tap(receivedFilter);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SegmentedButton<TransactionKind>>(
            find.byType(SegmentedButton<TransactionKind>),
          )
          .selected,
      {TransactionKind.received},
    );
    expect(
      find.descendant(of: find.byType(ExpenseTile), matching: find.text('Pay')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ExpenseTile),
        matching: find.text('Lunch'),
      ),
      findsNothing,
    );
    expect(find.text(r'$12.00'), findsWidgets);
    await tester.enterText(find.byType(TextField).first, 'lunch');
    await tester.pumpAndSettle();
    expect(find.text('No matches for "lunch"'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<TransactionKind>),
        matching: find.text('All'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(ExpenseTile),
        matching: find.text('Lunch'),
      ),
      findsOneWidget,
    );
  });
  testWidgets('small screen and large text remain scrollable with a keyboard', (
    tester,
  ) async {
    size(tester, size: const Size(360, 640));
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final p = await provider();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: p, child: const JudgyApp()),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Add transaction'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'settings groups expand inside a sheet without hidden ink or layout errors',
    (tester) async {
      size(tester);
      final p = await provider();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(value: p, child: const JudgyApp()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Budget and currency settings'));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      await tester.tap(find.text('Backup & restore'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Export backup'));
      await tester.pumpAndSettle();
      expect(find.text('Restore from file'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'editing only a note preserves original money and historical rate',
    (tester) async {
      size(tester);
      final p = await provider();
      final expense = Expense.fromEnteredAmount(
        id: 'yer',
        title: 'Yemeni coffee',
        enteredAmount: 200,
        currency: 'YER',
        exchangeRate: 540,
        date: now,
        category: 'Coffee',
      );
      await p.addExpense(expense);
      await p.updateSettings(600, 500);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(value: p, child: const JudgyApp()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Note (optional)'),
        'Keep receipt',
      );
      await tester.ensureVisible(find.text('Save expense'));
      await tester.tap(find.text('Save expense'));
      await tester.pumpAndSettle();
      final edited = p.expenses.single;
      expect(edited.note, 'Keep receipt');
      expect(edited.amountCents, expense.amountCents);
      expect(edited.originalAmountMinorUnits, 20000);
      expect(edited.exchangeRateAtEntry, 540);
    },
  );
}
