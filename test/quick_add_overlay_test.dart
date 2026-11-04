import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:judgy/models/expense.dart';
import 'package:judgy/providers/expense_provider.dart';
import 'package:judgy/screens/quick_add_overlay.dart';
import 'package:judgy/theme/app_theme.dart';
import 'package:judgy/widgets/app_lock_gate.dart';
import 'package:provider/provider.dart';

import 'support/memory_repository.dart';

void main() {
  testWidgets('notification quick add reuses an entry and saves it today', (
    tester,
  ) async {
    final today = DateTime(2026, 11, 3, 14);
    final provider = ExpenseProvider(
      repository: MemoryRepository(),
      clock: () => today,
    );
    await provider.initialized;
    await provider.addExpense(
      Expense.fromEnteredAmount(
        id: 'coffee',
        title: 'Coffee',
        enteredAmount: 1200,
        currency: 'YER',
        exchangeRate: 600,
        date: DateTime(2026, 10, 1),
        category: 'Food',
        note: 'Old note',
      ),
    );
    String? result;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          theme: AppTheme.dark.copyWith(
            scaffoldBackgroundColor: Colors.transparent,
          ),
          builder: (context, child) => AppLockGate(child: child!),
          home: QuickAddOverlay(
            onFinished: (message) async => result = message,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Quick picks'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quick-entry-coffee')));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextFormField, 'What you bought'),
      findsOneWidget,
    );
    expect(find.text('YER'), findsWidgets);
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(provider.expenses, hasLength(2));
    final copy = provider.expenses.first;
    expect(copy.id, isNot('coffee'));
    expect(copy.title, 'Coffee');
    expect(copy.category, 'Food');
    expect(copy.originalCurrency, 'YER');
    expect(copy.originalAmount, 1200);
    expect(copy.note, isNull);
    expect(copy.date, today);
    expect(result, 'Expense saved.');
  });

  testWidgets('quick add shows only the entry sheet and closes after save', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = ExpenseProvider(repository: MemoryRepository());
    await provider.initialized;
    String? result;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          theme: AppTheme.dark.copyWith(
            scaffoldBackgroundColor: Colors.transparent,
          ),
          builder: (context, child) => AppLockGate(child: child!),
          home: QuickAddOverlay(
            onFinished: (message) async {
              result = message;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add a transaction'), findsOneWidget);
    expect(find.text('Judgy'), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'What you bought'),
      'Coffee',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '3');
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(provider.expenses.single.title, 'Coffee');
    expect(result, 'Expense saved.');
  });

  testWidgets('dismissing quick add returns without saving', (tester) async {
    final provider = ExpenseProvider(repository: MemoryRepository());
    await provider.initialized;
    var finished = false;
    String? result;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          theme: AppTheme.dark.copyWith(
            scaffoldBackgroundColor: Colors.transparent,
          ),
          builder: (context, child) => AppLockGate(child: child!),
          home: QuickAddOverlay(
            onFinished: (message) async {
              result = message;
              finished = true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close transaction form'));
    await tester.pumpAndSettle();
    expect(finished, isTrue);
    expect(result, isNull);
    expect(provider.expenses, isEmpty);
  });
}
