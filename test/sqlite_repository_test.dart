import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:judgy/models/expense.dart';
import 'package:judgy/models/expense_state.dart';
import 'package:judgy/models/recurring_expense.dart';
import 'package:judgy/providers/expense_provider.dart';
import 'package:judgy/repositories/sqlite_expense_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/memory_repository.dart';

void main() {
  sqfliteFfiInit();
  final now = DateTime(2026, 10, 25, 12);
  late Directory directory;
  late SqliteExpenseRepository repository;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('judgy-sqlite-test-');
    repository = SqliteExpenseRepository(
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/judgy.db',
      legacy: MemoryRepository(),
    );
  });
  tearDown(() async {
    await repository.close();
    await directory.delete(recursive: true);
  });
  test(
    'migrates a validated preference backup and persists across reopen',
    () async {
      final legacy = MemoryRepository()
        ..source = ExpenseState(
          expenses: [
            Expense(
              id: 'legacy',
              title: 'Coffee',
              amountCents: 450,
              date: now,
              category: 'Coffee',
            ),
          ],
        ).encode();
      await repository.close();
      repository = SqliteExpenseRepository(
        factory: databaseFactoryFfi,
        databasePath: '${directory.path}/judgy.db',
        legacy: legacy,
      );
      final p = ExpenseProvider(repository: repository, clock: () => now);
      await p.initialized;
      expect(p.expenses.single.id, 'legacy');
      await p.addExpense(
        Expense(
          id: 'new',
          title: 'Lunch',
          amountCents: 1000,
          date: now,
          category: 'Food',
        ),
      );
      await repository.close();
      legacy.source = null;
      repository = SqliteExpenseRepository(
        factory: databaseFactoryFfi,
        databasePath: '${directory.path}/judgy.db',
        legacy: legacy,
      );
      final reopened = ExpenseProvider(
        repository: repository,
        clock: () => now,
      );
      await reopened.initialized;
      expect(reopened.expenses.map((e) => e.id).toSet(), {'legacy', 'new'});
    },
  );
  test('SQLite charge and recurring marker survive together', () async {
    final p = ExpenseProvider(repository: repository, clock: () => now);
    await p.initialized;
    await p.addRecurring(
      const RecurringExpense(
        id: 'rent',
        title: 'Rent',
        amountCents: 1000,
        category: 'Other',
        dayOfMonth: 1,
      ),
    );
    expect(await p.applyRecurring('rent'), isTrue);
    final state = ExpenseState.decode((await repository.read())!);
    expect(state.expenses.single.id, 'recurring:rent:202610');
    expect(state.recurring.single.lastApplied, now);
  });
  test(
    'SQLite keeps pre-import history and reset clears the recovery copy',
    () async {
      final p = ExpenseProvider(repository: repository, clock: () => now);
      await p.initialized;
      await p.addExpense(
        Expense(
          id: 'old',
          title: 'Old',
          amountCents: 100,
          date: now,
          category: 'Other',
        ),
      );
      expect(await p.importState(const ExpenseState().encode()), isTrue);
      expect(
        ExpenseState.decode(
          (await repository.readRecovery())!,
        ).expenses.single.id,
        'old',
      );
      expect(await p.resetStorage(), isTrue);
      expect(await repository.readRecovery(), isNull);
      expect(ExpenseState.decode((await repository.read())!).expenses, isEmpty);
    },
  );
  test(
    'a malformed write is rejected without replacing durable data',
    () async {
      await repository.write(const ExpenseState().encode());
      final before = await repository.read();
      await expectLater(repository.write('{broken'), throwsFormatException);
      expect(await repository.read(), before);
    },
  );
  test(
    'a failure after row updates rolls back the entire SQLite transaction',
    () async {
      final p = ExpenseProvider(repository: repository, clock: () => now);
      await p.initialized;
      await p.addRecurring(
        const RecurringExpense(
          id: 'rent',
          title: 'Rent',
          amountCents: 1000,
          category: 'Other',
          dayOfMonth: 1,
        ),
      );
      final db = await databaseFactoryFfi.openDatabase(
        '${directory.path}/judgy.db',
      );
      await db.execute(
        "CREATE TRIGGER reject_settings BEFORE INSERT ON settings BEGIN SELECT RAISE(ABORT, 'injected failure'); END",
      );
      expect(await p.applyRecurring('rent'), isFalse);
      final state = ExpenseState.decode((await repository.read())!);
      expect(state.expenses, isEmpty);
      expect(state.recurring.single.lastApplied, isNull);
      await db.execute('DROP TRIGGER reject_settings');
      expect(await p.applyRecurring('rent'), isTrue);
    },
  );
}
