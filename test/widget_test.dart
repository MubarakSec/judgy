import 'dart:ui' as ui;

import 'package:judgy/main.dart';
import 'package:judgy/models/expense.dart';
import 'package:judgy/providers/expense_provider.dart';
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
    expect(find.text('Add first expense'), findsOneWidget);

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

    await tester.tap(find.text('Add first expense'));
    await tester.pumpAndSettle();
    expect(find.text('Add an expense'), findsOneWidget);

    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(find.text('Enter what you spent money on.'), findsOneWidget);
    expect(find.text('Enter a valid amount.'), findsOneWidget);
  });

  testWidgets('adds, deletes, and restores an expense', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Add first expense'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Expense name'),
      'Lunch',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount'),
      '12.50',
    );
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();

    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text(r'-$12.50'), findsOneWidget);
    expect(find.textContaining('Saved.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Lunch'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Lunch'), findsOneWidget);
  });

  testWidgets('compact-height layout remains scrollable without overflow', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(430, 600));

    final addButton = find.text('Add first expense');
    await tester.ensureVisible(addButton);
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

    await tester.drag(find.text('Swipe test'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Swipe test'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Swipe test'), findsOneWidget);
  });
}
