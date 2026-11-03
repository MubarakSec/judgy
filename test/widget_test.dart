import 'dart:ui' as ui;

import 'package:judgy/main.dart';
import 'package:judgy/models/expense.dart';
import 'package:judgy/providers/expense_provider.dart';
import 'package:judgy/widgets/expense_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ExpenseProvider> pumpApp(
    WidgetTester tester, {
    Size size = const Size(430, 932),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final provider = ExpenseProvider(clock: () => DateTime(2026, 7, 12, 12));
    await provider.initialized;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: provider, child: const JudgyApp()),
    );
    await tester.pumpAndSettle();
    return provider;
  }

  testWidgets('shows a clear first-run state and semantic period selection', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Judgy'), findsOneWidget);
    expect(find.text('Spent this month'), findsOneWidget);
    expect(find.text('Ready when you are'), findsOneWidget);
    expect(find.text('Add transaction'), findsOneWidget);

    final monthSemantics = tester.getSemantics(find.text('Month'));
    expect(
      monthSemantics.getSemanticsData().flagsCollection.isSelected,
      ui.Tristate.isTrue,
    );
  });

  testWidgets('empty expense submission shows inline validation', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Add transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Add a transaction'), findsOneWidget);

    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name for this transaction.'), findsOneWidget);
    expect(find.text('Enter a valid amount.'), findsOneWidget);
  });

  testWidgets('adds, deletes, and restores an expense', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Add transaction'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'What you bought'),
      'Lunch',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount'),
      '12.50',
    );
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(ExpenseTile),
        matching: find.text('Lunch'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ExpenseTile),
        matching: find.text(r'-$12.50'),
      ),
      findsOneWidget,
    );
    expect(find.text('Expense saved.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Lunch'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(ExpenseTile),
        matching: find.text('Lunch'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('records income and shows it as received', (tester) async {
    final provider = await pumpApp(tester);
    await tester.tap(find.text('Add transaction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Received').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Where it came from'),
      'Pay',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '25');
    await tester.tap(find.text('Save income'));
    await tester.pumpAndSettle();
    expect(provider.expenses.single.isIncome, isTrue);
    expect(provider.totalSpentCents, 0);
    expect(provider.totalIncomeCents, 2500);
    expect(
      find.descendant(
        of: find.byType(ExpenseTile),
        matching: find.text(r'+$25.00'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'keyboard Done saves a basic transaction without opening details',
    (tester) async {
      final provider = await pumpApp(tester);
      await tester.tap(find.text('Add transaction'));
      await tester.pumpAndSettle();
      expect(find.text('Date and note'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Note (optional)'),
        findsNothing,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'What you bought'),
        'Bus fare',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '2.50',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(provider.expenses.single.title, 'Bus fare');
      expect(provider.expenses.single.amountCents, 250);
      expect(provider.expenses.single.category, 'Other');
    },
  );

  testWidgets('Add again prefills a recent entry with today as the date', (
    tester,
  ) async {
    final provider = await pumpApp(tester);
    await provider.addExpense(
      Expense(
        id: 'old-coffee',
        title: 'Coffee',
        amountCents: 350,
        date: DateTime(2026, 7, 10),
        category: 'Coffee',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quick-entry-old-coffee')));
    await tester.pumpAndSettle();
    expect(find.text('Add again'), findsWidgets);
    expect(
      find.widgetWithText(TextFormField, 'What you bought'),
      findsOneWidget,
    );
    expect(find.text('3.50'), findsOneWidget);
    await tester.ensureVisible(find.text('Save expense'));
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(provider.expenses, hasLength(2));
    expect(provider.expenses.first.date, DateTime(2026, 7, 12, 12));
    expect(provider.expenses.first.category, 'Coffee');
  });

  testWidgets('transaction menu pins and unpins a quick entry', (tester) async {
    final provider = await pumpApp(tester);
    await provider.addExpense(
      Expense(
        id: 'bus',
        title: 'Bus',
        amountCents: 250,
        date: DateTime(2026, 7, 12, 9),
        category: 'Transport',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More actions for Bus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pin to quick add'));
    await tester.pumpAndSettle();
    expect(provider.isQuickEntryPinned('bus'), isTrue);
    expect(find.byKey(const ValueKey('quick-entry-bus')), findsOneWidget);

    await tester.tap(find.byTooltip('More actions for Bus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unpin quick entry'));
    await tester.pumpAndSettle();
    expect(provider.isQuickEntryPinned('bus'), isFalse);
  });

  testWidgets('compact-height layout remains scrollable without overflow', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(430, 600));

    final addButton = find.text('Add transaction');
    await tester.pumpAndSettle();
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    final saveButton = find.text('Save expense');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    expect(saveButton, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swipe deletion also exposes Undo and restores the row', (
    tester,
  ) async {
    final provider = await pumpApp(tester);
    await provider.addExpense(
      Expense(
        id: 'swipe-test',
        title: 'Swipe test',
        amountCents: 500,
        date: DateTime(2026, 7, 12, 10),
        category: 'Other',
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ExpenseTile), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Swipe test'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(ExpenseTile),
        matching: find.text('Swipe test'),
      ),
      findsOneWidget,
    );
  });
}
