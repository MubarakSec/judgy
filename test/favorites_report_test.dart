import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:judgy/main.dart';
import 'package:judgy/models/expense.dart';
import 'package:judgy/models/expense_state.dart';
import 'package:judgy/models/favorite_template.dart';
import 'package:judgy/models/ledger_category.dart';
import 'package:judgy/providers/expense_provider.dart';
import 'package:judgy/screens/insights_sheet.dart';
import 'package:judgy/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'support/memory_repository.dart';

void main() {
  final now = DateTime(2026, 11, 4, 12);
  Future<ExpenseProvider> open(MemoryRepository repository) async {
    final provider = ExpenseProvider(repository: repository, clock: () => now);
    await provider.initialized;
    return provider;
  }

  test(
    'monthly category totals split spent and received and ignore other dates',
    () async {
      final p = await open(MemoryRepository());
      Future<void> add(
        String id,
        String category,
        int cents,
        String type,
        DateTime date,
      ) async {
        expect(
          await p.addExpense(
            Expense(
              id: id,
              title: id,
              amountCents: cents,
              date: date,
              category: category,
              type: type,
            ),
          ),
          isTrue,
        );
      }

      await add('a', 'Other', 400, 'expense', now);
      await add('b', 'Other', 250, 'expense', DateTime(2026, 11, 2));
      await add('c', 'Other', 900, 'income', now);
      await add('old', 'Other', 1000, 'expense', DateTime(2026, 10, 31));
      await add('future', 'Other', 3000, 'income', DateTime(2026, 11, 5));
      expect(p.monthlyCategoryTotals('expense'), {'Other': 650});
      expect(p.monthlyCategoryTotals('income'), {'Other': 900});
      expect(p.monthlyCategoryCount('expense', category: 'Other'), 2);
      expect(p.monthlyCategoryCount('income', category: 'Other'), 1);
    },
  );

  test(
    'favorites persist without transactions and follow category rename',
    () async {
      final repository = MemoryRepository();
      final p = await open(repository);
      await p.addCategory(
        const LedgerCategory(
          label: 'Transit',
          type: 'expense',
          iconKey: 'transport',
        ),
      );
      const item = FavoriteTemplate(
        id: 'bus',
        title: 'Bus pass',
        amountMinorUnits: 250,
        currency: 'USD',
        category: 'Transit',
        type: 'expense',
      );
      expect(await p.addFavorite(item), isTrue);
      expect(p.expenses, isEmpty);
      expect(
        await p.updateFavorite(item.copyWith(amountMinorUnits: 375)),
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
      expect(p.favorites.single.category, 'Travel');
      expect(await p.removeCategory('Travel', 'expense'), isFalse);
      final reloaded = await open(repository);
      expect(reloaded.favorites.single.amountMinorUnits, 375);
      expect(reloaded.favorites.single.category, 'Travel');
      expect(
        ExpenseState.decode(reloaded.exportState()).favorites.single.id,
        'bus',
      );
      expect(await reloaded.removeFavorite('bus'), isTrue);
      expect((await open(repository)).favorites, isEmpty);
    },
  );

  test(
    'older backup has no favorites; invalid favorites do not replace state',
    () async {
      final state = ExpenseState().toMap()..remove('favorites');
      expect(ExpenseState.decode(jsonEncode(state)).favorites, isEmpty);
      final repository = MemoryRepository();
      final p = await open(repository);
      final before = p.exportState();
      final invalid = jsonDecode(before) as Map<String, dynamic>;
      invalid['favorites'] = [
        {'id': 'broken'},
      ];
      expect(await p.importState(jsonEncode(invalid)), isFalse);
      expect(p.exportState(), before);
    },
  );

  testWidgets(
    'report filters category and direction with exact monthly totals',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final p = await open(MemoryRepository());
      await p.addExpense(
        Expense(
          id: 'coffee',
          title: 'Coffee',
          amountCents: 350,
          date: now,
          category: 'Coffee',
        ),
      );
      await p.addExpense(
        Expense(
          id: 'salary',
          title: 'Salary',
          amountCents: 50000,
          date: now,
          category: 'Salary',
          type: 'income',
        ),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: p,
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const Scaffold(body: InsightsSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('By category'));
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coffee').last);
      await tester.pumpAndSettle();
      expect(find.text(r'$3.50'), findsWidgets);
      expect(find.text('1 entry'), findsOneWidget);
      await tester.tap(
        find
            .descendant(
              of: find.byType(SegmentedButton<String>),
              matching: find.text('Received'),
            )
            .last,
      );
      await tester.pumpAndSettle();
      expect(find.text(r'$500.00'), findsWidgets);
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salary').last);
      await tester.pumpAndSettle();
      expect(find.text('1 entry'), findsOneWidget);
    },
  );

  testWidgets('create and reuse favorite from the add sheet', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final p = await open(MemoryRepository());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: p, child: const JudgyApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add transaction'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-favorite')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Bus');
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextFormField, 'Amount'),
      ),
      '2.50',
    );
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    expect(p.favorites.single.title, 'Bus');
    expect(p.expenses, isEmpty);
    await tester.tap(find.byKey(ValueKey('favorite-${p.favorites.single.id}')));
    await tester.pumpAndSettle();
    expect(find.text('2.50'), findsOneWidget);
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(p.expenses.single.amountCents, 250);
    expect(p.favorites.single.title, 'Bus');
  });

  testWidgets('favorite manager edits and removes a saved shortcut', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final p = await open(MemoryRepository());
    await p.addFavorite(
      const FavoriteTemplate(
        id: 'bus',
        title: 'Bus',
        amountMinorUnits: 250,
        currency: 'USD',
        category: 'Other',
        type: 'expense',
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: p, child: const JudgyApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add transaction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bus').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextFormField, 'Amount'),
      ),
      '3.75',
    );
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    expect(p.favorites.single.amountMinorUnits, 375);
    await tester.tap(find.text('Bus').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    expect(p.favorites, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('report and favorite editor fit a small large-text screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final p = await open(MemoryRepository());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: p,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: InsightsSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: p, child: const JudgyApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add transaction'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-favorite')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
