import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/expense_state.dart';
import '../services/local_snapshots.dart';
import 'expense_repository.dart';

/// Expenses and recurring markers are committed together. Unchanged records
/// are retained, so updating one expense does not rewrite the entire history.
class SqliteExpenseRepository implements ExpenseRepository {
  SqliteExpenseRepository({
    DatabaseFactory? factory,
    String? databasePath,
    ExpenseRepository? legacy,
    LocalSnapshots? snapshots,
  }) : _factory = factory ?? databaseFactory,
       _path = databasePath,
       _legacy = legacy ?? PreferencesExpenseRepository(),
       _snapshots =
           snapshots ?? (databasePath == null ? LocalSnapshots() : null);

  final DatabaseFactory _factory;
  final String? _path;
  final ExpenseRepository _legacy;
  final LocalSnapshots? _snapshots;
  Future<Database>? _opening;

  Future<Database> get _database => _opening ??= _open();

  Future<Database> _open() async {
    final location =
        _path ?? path.join(await _factory.getDatabasesPath(), 'judgy.db');
    return _factory.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA journal_mode = WAL');
        },
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE settings (id INTEGER PRIMARY KEY CHECK(id = 1), data TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE expenses (id TEXT PRIMARY KEY, date TEXT NOT NULL, data TEXT NOT NULL)',
          );
          await db.execute('CREATE INDEX expenses_date ON expenses(date DESC)');
          await db.execute(
            'CREATE TABLE recurring (id TEXT PRIMARY KEY, data TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE recovery (id INTEGER PRIMARY KEY CHECK(id = 1), data TEXT NOT NULL)',
          );
        },
      ),
    );
  }

  @override
  Future<String?> read() async {
    final db = await _database;
    return db.transaction((txn) async {
      final settings = await txn.query('settings');
      if (settings.isEmpty) return _legacy.read();
      final state = Map<String, dynamic>.from(
        jsonDecode(settings.single['data'] as String) as Map,
      );
      state['expenses'] = (await txn.query(
        'expenses',
        orderBy: 'date DESC',
      )).map((r) => jsonDecode(r['data'] as String)).toList();
      state['recurringExpenses'] = (await txn.query(
        'recurring',
      )).map((r) => jsonDecode(r['data'] as String)).toList();
      return jsonEncode(state);
    });
  }

  @override
  Future<void> write(
    String source, {
    String? recovery,
    bool reset = false,
  }) async {
    final state = ExpenseState.decode(source).toMap();
    final expenses = (state.remove('expenses') as List)
        .cast<Map<String, dynamic>>();
    final recurring = (state.remove('recurringExpenses') as List)
        .cast<Map<String, dynamic>>();
    final db = await _database;
    await db.transaction((txn) async {
      if (recovery != null) {
        await txn.insert('recovery', {
          'id': 1,
          'data': recovery,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      if (reset) await txn.delete('recovery');
      await _syncRows(txn, 'expenses', expenses);
      await _syncRows(txn, 'recurring', recurring);
      await txn.insert('settings', {
        'id': 1,
        'data': jsonEncode(state),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    // The financial transaction is already durable. Snapshot failures must not
    // make the caller retry a successfully committed expense.
    try {
      if (reset) {
        await _snapshots?.clear();
        if (_legacy is PreferencesExpenseRepository) {
          await _legacy.clearLegacy();
        }
      } else if (expenses.isNotEmpty) {
        await _snapshots?.saveIfDue(source, DateTime.now());
      }
    } catch (_) {
      /* Export remains available if app-private snapshots fail. */
    }
  }

  Future<void> _syncRows(
    Transaction txn,
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    // Table names are internal constants. User data is always bound.
    final existing = {
      for (final r in await txn.query(table, columns: ['id', 'data']))
        r['id'] as String: r['data'] as String,
    };
    final batch = txn.batch();
    for (final row in rows) {
      final id = row['id'] as String;
      final encoded = jsonEncode(row);
      if (existing.remove(id) == encoded) continue;
      batch.insert(table, {
        'id': id,
        'data': encoded,
        if (table == 'expenses') 'date': row['date'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final id in existing.keys) {
      batch.delete(table, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<String?> readRecovery() async {
    final rows = await (await _database).query('recovery');
    return rows.isEmpty ? null : rows.single['data'] as String;
  }

  @override
  Future<Map<String, Object>> readLegacy() => _legacy.readLegacy();

  Future<void> close() async {
    if (_opening != null) await (await _opening!).close();
  }
}
