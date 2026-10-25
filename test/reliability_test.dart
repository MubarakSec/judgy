import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:judgy/models/expense.dart';
import 'package:judgy/models/expense_state.dart';
import 'package:judgy/models/recurring_expense.dart';
import 'package:judgy/providers/expense_provider.dart';
import 'support/memory_repository.dart';
import 'package:judgy/utils/expense_csv.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime(2026, 2, 28, 12);
  Expense expense(String id) => Expense(
    id: id,
    title: 'Lunch',
    amountCents: 100,
    date: now,
    category: 'Food',
    note: 'Receipt, saved\nSecond line',
  );
  ExpenseProvider create(
    MemoryRepository repo, {
    Future<void> Function(int)? alert,
  }) => ExpenseProvider(repository: repo, clock: () => now, budgetAlert: alert);
  const rent = RecurringExpense(
    id: 'rent',
    title: 'Rent',
    amountCents: 100,
    category: 'Other',
    dayOfMonth: 31,
  );
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('invalid imports preserve history and persisted state', () async {
    final repo = MemoryRepository();
    final p = create(repo);
    await p.initialized;
    await p.addExpense(expense('one'));
    final before = repo.source;
    for (final invalid in [
      '{"version":2}',
      '{"version":999}',
      'null',
      '{broken',
    ]) {
      expect(await p.importState(invalid), isFalse);
      expect(repo.source, before);
      expect(p.expenses.single.id, 'one');
    }
    for (final invalid in [
      '',
      'wrong,header\nx,y',
      p.exportCsv().replaceFirst('one,', '"one,'),
    ]) {
      expect(await p.importCsv(invalid), isFalse);
      expect(repo.source, before);
    }
  });
  test(
    'failed import and ordinary writes leave memory and disk unchanged',
    () async {
      final repo = MemoryRepository();
      final p = create(repo);
      await p.initialized;
      await p.addExpense(expense('one'));
      final before = repo.source;
      final replacement = ExpenseState(expenses: [expense('two')]).encode();
      repo.failWrites = true;
      expect(await p.importState(replacement), isFalse);
      expect(await p.addExpense(expense('three')), isFalse);
      expect(p.expenses.map((e) => e.id), ['one']);
      expect(repo.source, before);
      repo.failWrites = false;
      expect(await p.addExpense(expense('four')), isTrue);
    },
  );
  test(
    'successful import retains a recovery copy and the device lock',
    () async {
      final repo = MemoryRepository();
      final p = create(repo);
      await p.initialized;
      await p.addExpense(expense('one'));
      await p.setRequireBiometric(true);
      expect(await p.importState(const ExpenseState().encode()), isTrue);
      expect(p.requireBiometric, isTrue);
      expect(p.expenses, isEmpty);
      expect(
        ExpenseState.decode((await p.recoveryBackup())!).expenses.single.id,
        'one',
      );
    },
  );
  test('rapid recurring applications create one persisted charge', () async {
    final repo = MemoryRepository();
    final p = create(repo);
    await p.initialized;
    await p.addRecurring(rent);
    final results = await Future.wait([
      p.applyRecurring('rent'),
      p.applyRecurring('rent'),
    ]);
    expect(results, [true, false]);
    expect(p.expenses, hasLength(1));
    final reopened = create(repo);
    await reopened.initialized;
    expect(await reopened.applyRecurring('rent'), isFalse);
  });
  test(
    'failed recurring transaction commits neither expense nor marker',
    () async {
      final repo = MemoryRepository();
      final p = create(repo);
      await p.initialized;
      await p.addRecurring(rent);
      repo.failWrites = true;
      expect(await p.applyRecurring('rent'), isFalse);
      expect(p.expenses, isEmpty);
      expect(p.recurringExpenses.single.lastApplied, isNull);
      repo.failWrites = false;
      expect(await p.applyRecurring('rent'), isTrue);
    },
  );
  test('auto apply clamps month end and runs when enabled', () async {
    final repo = MemoryRepository();
    final p = create(repo);
    await p.initialized;
    await p.addRecurring(rent);
    expect(await p.setAutoApplyRecurring(true), isTrue);
    expect(p.expenses.single.date, DateTime(2026, 2, 28));
    await p.reconcileRecurring();
    expect(p.expenses, hasLength(1));
  });
  test('invalid recurring backup finishes loading and blocks writes', () async {
    final repo = MemoryRepository()
      ..source = jsonEncode(
        const ExpenseState().toMap()
          ..['autoApplyRecurring'] = true
          ..['recurringExpenses'] = [rent.toMap()..['amountCents'] = 0],
      );
    final original = repo.source;
    final p = create(repo);
    await p.initialized;
    expect(p.isLoading, isFalse);
    expect(p.loadFailed, isTrue);
    expect(await p.addExpense(expense('one')), isFalse);
    expect(repo.source, original);
  });
  test('reset does not resurrect legacy expenses', () async {
    SharedPreferences.setMockInitialValues({
      'expenses': [expense('legacy').toJson()],
    });
    final p = ExpenseProvider(clock: () => now);
    await p.initialized;
    expect(await p.resetStorage(), isTrue);
    final reopened = ExpenseProvider(clock: () => now);
    await reopened.initialized;
    expect(reopened.expenses, isEmpty);
  });
  test('CSV preserves notes, quotes and spreadsheet-like text', () {
    final row = expense('one').toMap()..['title'] = '=SUM(1,2)';
    final csv = ExpenseCsv.encode([row]);
    expect(csv, contains("'=SUM"));
    expect(ExpenseCsv.decode(csv).single, row);
    expect(
      () => ExpenseCsv.decode('id,title,amountCents,date,category\n"unclosed'),
      throwsFormatException,
    );
  });
  test(
    'a notification failure never turns a committed expense into failure',
    () async {
      final repo = MemoryRepository();
      final p = create(
        repo,
        alert: (_) async => throw StateError('permission denied'),
      );
      await p.initialized;
      await p.updateSettings(540, 1);
      expect(await p.addExpense(expense('one')), isTrue);
      expect(p.expenses, hasLength(1));
    },
  );
  test('duplicate imported IDs are rejected before any replacement', () async {
    final repo = MemoryRepository();
    final p = create(repo);
    await p.initialized;
    await p.addExpense(expense('original'));
    final before = repo.source;
    expect(
      await p.importState(
        ExpenseState(expenses: [expense('x'), expense('x')]).encode(),
      ),
      isFalse,
    );
    expect(repo.source, before);
  });
}
