import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:judgy/main.dart';
import 'package:judgy/models/expense.dart';
import 'package:judgy/providers/expense_provider.dart';
import 'package:judgy/screens/add_expense_sheet.dart';
import 'package:judgy/services/voice_input_controller.dart';
import 'package:judgy/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'support/memory_repository.dart';

class TranscriptVoice extends VoiceInputController {
  TranscriptVoice(this.phrase);
  final String phrase;
  @override
  Future<void> start({required String locale, required bool onDevice}) async {
    transcript = phrase;
    isFinal = true;
    isListening = false;
    notifyListeners();
  }

  @override
  Future<void> cancel() async {
    isListening = false;
  }
}

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
    await tester.tap(find.byTooltip('Sort expenses'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('Highest amount'),
        matching: find.byType(CheckedPopupMenuItem<String>),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Large lunch')).dy,
      lessThan(tester.getTopLeft(find.text('Cheap coffee')).dy),
    );
    await tester.enterText(find.byType(TextField).first, 'coffee');
    await tester.pumpAndSettle();
    expect(find.text('Large lunch'), findsNothing);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Large lunch'), findsOneWidget);
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
    await tester.scrollUntilVisible(
      find.text('Add first expense'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Add first expense'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'voice preview does not overwrite an existing form without confirmation',
    (tester) async {
      size(tester);
      final p = await provider();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: p,
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: AddExpenseSheet(
                voiceController: TranscriptVoice('coffee please'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Expense name'),
        'Manual lunch',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '7');
      await tester.tap(find.byTooltip('Add by voice'));
      await tester.pumpAndSettle();
      expect(find.text('Manual lunch'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      final use = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Use entry'),
      );
      expect(use.onPressed, isNull);
      expect(p.expenses, isEmpty);
    },
  );
  testWidgets(
    'confirmed voice uses spoken currency and remains editable before saving',
    (tester) async {
      size(tester);
      final p = await provider();
      await p.toggleCurrency();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: p,
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: AddExpenseSheet(
                voiceController: TranscriptVoice(
                  'coffee four dollars yesterday',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add by voice'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Use entry'));
      await tester.tap(find.text('Use entry'));
      await tester.pumpAndSettle();
      expect(find.text('coffee'), findsOneWidget);
      expect(find.text('4.0'), findsOneWidget);
      expect(p.expenses, isEmpty);
      final dropdown = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>).first,
      );
      expect(dropdown.value, 'USD');
      await tester.ensureVisible(find.text('Save expense'));
      await tester.tap(find.text('Save expense'));
      await tester.pumpAndSettle();
      expect(p.expenses.single.amountCents, 400);
      expect(p.expenses.single.originalCurrency, 'USD');
      expect(p.expenses.single.date, DateTime(2026, 10, 24));
    },
  );
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
