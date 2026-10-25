import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/expense.dart';
import '../models/expense_state.dart';
import '../models/recurring_expense.dart';
import '../repositories/expense_repository.dart';
import '../services/quick_add_notifications.dart';
import '../utils/expense_csv.dart';

class ExpenseRemoval {
  const ExpenseRemoval({required this.expense, required this.index});
  final Expense expense;
  final int index;
}

class ExpenseProvider with ChangeNotifier {
  ExpenseProvider({
    DateTime Function()? clock,
    ExpenseRepository? repository,
    Future<void> Function(int)? budgetAlert,
  }) : _clock = clock ?? DateTime.now,
       _repository = repository ?? PreferencesExpenseRepository(),
       _budgetAlert =
           budgetAlert ??
           ((level) => QuickAddNotifications.showBudgetAlert(
             percentage: level,
             overBudget: level >= 100,
           )) {
    _initialized = _loadData();
  }

  final DateTime Function() _clock;
  final ExpenseRepository _repository;
  final Future<void> Function(int) _budgetAlert;
  ExpenseState _state = const ExpenseState();
  late final Future<void> _initialized;
  Future<void> _queue = Future.value();
  bool _disposed = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _loadFailed = false;
  String? _warningMessage;
  String? _errorMessage;
  String _timeFilter = 'Month';
  DateTime? _customRangeStart;
  DateTime? _customRangeEnd;

  UnmodifiableListView<Expense> get expenses =>
      UnmodifiableListView(_state.expenses);
  UnmodifiableListView<RecurringExpense> get recurringExpenses =>
      UnmodifiableListView(_state.recurring);
  bool get autoApplyRecurring => _state.autoApplyRecurring;
  bool get requireBiometric => _state.requireBiometric;
  String get voiceLocale => _state.voiceLocale;
  bool get voiceOnDevice => _state.voiceOnDevice;
  DateTime get now => _clock();
  bool get isUSD => _state.isUSD;
  double get exchangeRate => _state.exchangeRate;
  int get monthlyBudgetCents => _state.budgetCents;
  double get monthlyBudget => monthlyBudgetCents / 100;
  String get timeFilter => _timeFilter;
  DateTime? get customRangeStart => _customRangeStart;
  DateTime? get customRangeEnd => _customRangeEnd;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get loadFailed => _loadFailed;
  String? get warningMessage => _warningMessage;
  String? get errorMessage => _errorMessage;
  int get lastBudgetAlertLevel => _state.lastBudgetAlertLevel;
  Future<void> get initialized => _initialized;

  List<Expense> get filteredExpenses {
    final current = now;
    final start = switch (_timeFilter) {
      'Day' => _startOfDay(current),
      'Week' => _startOfDay(
        current,
      ).subtract(Duration(days: current.weekday - 1)),
      'Custom' => _customRangeStart ?? _startOfDay(current),
      _ => DateTime(current.year, current.month),
    };
    final end = _timeFilter == 'Custom' ? _customRangeEnd ?? current : current;
    return _state.expenses
        .where((e) => !e.date.isBefore(start) && !e.date.isAfter(end))
        .toList();
  }

  int get totalSpentCents =>
      filteredExpenses.fold(0, (sum, e) => sum + e.amountCents);
  int _monthlyTotal(ExpenseState state) {
    final current = now;
    final start = DateTime(current.year, current.month);
    return state.expenses
        .where((e) => !e.date.isBefore(start) && !e.date.isAfter(current))
        .fold(0, (sum, e) => sum + e.amountCents);
  }

  int get monthlySpentCents => _monthlyTotal(_state);
  int get monthlyRemainingCents => monthlyBudgetCents - monthlySpentCents;
  double get budgetProgress => monthlyBudgetCents <= 0
      ? 0
      : (monthlySpentCents / monthlyBudgetCents).clamp(0.0, 1.0);
  bool get isOverBudget =>
      monthlyBudgetCents > 0 && monthlySpentCents > monthlyBudgetCents;
  Map<String, int> get categoryTotals {
    final start = DateTime(now.year, now.month);
    final totals = <String, int>{};
    for (final e in _state.expenses) {
      if (e.date.isBefore(start) || e.date.isAfter(now)) continue;
      totals.update(
        e.category,
        (value) => value + e.amountCents,
        ifAbsent: () => e.amountCents,
      );
    }
    return totals;
  }

  int get previousMonthSpentCents {
    final start = DateTime(now.year, now.month - 1);
    final end = DateTime(now.year, now.month);
    return _state.expenses
        .where((e) => !e.date.isBefore(start) && e.date.isBefore(end))
        .fold(0, (sum, e) => sum + e.amountCents);
  }

  int get previousComparableSpentCents {
    final current = now;
    final days = DateTime(current.year, current.month, 0).day;
    final end = DateTime(
      current.year,
      current.month - 1,
      current.day.clamp(1, days),
      current.hour,
      current.minute,
      current.second,
      current.millisecond,
      current.microsecond,
    );
    final start = DateTime(current.year, current.month - 1);
    return _state.expenses
        .where((e) => !e.date.isBefore(start) && !e.date.isAfter(end))
        .fold(0, (sum, e) => sum + e.amountCents);
  }

  int get dailyAverageCents => (monthlySpentCents / now.day).round();
  double get monthOverMonthChange => previousComparableSpentCents == 0
      ? double.nan
      : (monthlySpentCents - previousComparableSpentCents) /
            previousComparableSpentCents;

  void setTimeFilter(String filter) {
    if (!{'Day', 'Week', 'Month', 'Custom'}.contains(filter)) return;
    _timeFilter = filter;
    _notify();
  }

  void setCustomRange(DateTime start, DateTime end) {
    if (end.isBefore(start)) return;
    _customRangeStart = _startOfDay(start);
    _customRangeEnd = DateTime(
      end.year,
      end.month,
      end.day + 1,
    ).subtract(const Duration(microseconds: 1));
    _timeFilter = 'Custom';
    _notify();
  }

  void clearWarning() {
    _warningMessage = null;
    _notify();
  }

  void clearError() {
    _errorMessage = null;
    _notify();
  }

  Future<bool> toggleCurrency() => _mutate((s) => s.copyWith(isUSD: !s.isUSD));
  Future<bool> updateSettings(double rate, double budget) {
    if (!rate.isFinite ||
        rate <= 0 ||
        rate > 1000000 ||
        !budget.isFinite ||
        budget < 0 ||
        budget > 9007199254740991 / 100) {
      _errorMessage =
          'Enter a rate above zero (up to 1,000,000) and a valid budget.';
      _notify();
      return Future.value(false);
    }
    return _mutate(
      (s) =>
          s.copyWith(exchangeRate: rate, budgetCents: (budget * 100).round()),
    );
  }

  Future<bool> setRequireBiometric(bool value) =>
      _mutate((s) => s.copyWith(requireBiometric: value));
  Future<bool> setVoicePreferences({
    required String locale,
    required bool onDevice,
  }) =>
      _mutate((s) => s.copyWith(voiceLocale: locale, voiceOnDevice: onDevice));
  Future<bool> setAutoApplyRecurring(bool value) => _mutate((s) {
    final updated = s.copyWith(autoApplyRecurring: value);
    return value ? _dueRecurring(updated) : updated;
  });

  Future<bool> addExpense(Expense expense) => _mutate((s) {
    if (s.expenses.any((e) => e.id == expense.id)) {
      throw const FormatException('An expense with this ID already exists.');
    }
    return s.copyWith(expenses: _sorted([...s.expenses, expense]));
  });
  Future<bool> updateExpense(Expense expense) => _mutate((s) {
    if (!s.expenses.any((e) => e.id == expense.id)) {
      throw const FormatException('Expense no longer exists.');
    }
    return s.copyWith(
      expenses: _sorted(
        s.expenses.map((e) => e.id == expense.id ? expense : e).toList(),
      ),
    );
  });
  Future<ExpenseRemoval?> removeExpense(String id) async {
    ExpenseRemoval? removal;
    final saved = await _mutate((s) {
      final index = s.expenses.indexWhere((e) => e.id == id);
      if (index < 0) throw const FormatException('Expense no longer exists.');
      removal = ExpenseRemoval(expense: s.expenses[index], index: index);
      return s.copyWith(expenses: [...s.expenses]..removeAt(index));
    });
    return saved ? removal : null;
  }

  Future<bool> restoreExpense(ExpenseRemoval removal) => _mutate((s) {
    if (s.expenses.any((e) => e.id == removal.expense.id)) return s;
    return s.copyWith(expenses: _sorted([...s.expenses, removal.expense]));
  });
  Future<bool> addRecurring(RecurringExpense item) => _mutate((s) {
    item.validate();
    if (s.recurring.any((e) => e.id == item.id)) {
      throw const FormatException('Recurring template already exists.');
    }
    final updated = s.copyWith(recurring: [...s.recurring, item]);
    return s.autoApplyRecurring ? _dueRecurring(updated) : updated;
  });
  Future<bool> removeRecurring(String id) => _mutate(
    (s) => s.copyWith(recurring: s.recurring.where((e) => e.id != id).toList()),
  );
  Future<bool> applyRecurring(String id) =>
      _mutate((s) => _applyRecurring(s, id));

  ExpenseState _applyRecurring(ExpenseState state, String id) {
    final item = state.recurring.where((e) => e.id == id).firstOrNull;
    if (item == null) {
      throw const FormatException('Recurring template no longer exists.');
    }
    item.validate();
    final current = now;
    final month = current.year * 100 + current.month;
    final applied = item.lastApplied;
    if (applied != null && applied.year * 100 + applied.month >= month) {
      throw const FormatException(
        'This recurring expense was already applied this month.',
      );
    }
    final expenseId = 'recurring:$id:$month';
    if (state.expenses.any((e) => e.id == expenseId)) {
      throw const FormatException(
        'This recurring expense was already applied this month.',
      );
    }
    final day = item.dayOfMonth.clamp(
      1,
      DateTime(current.year, current.month + 1, 0).day,
    );
    final expense = Expense(
      id: expenseId,
      title: item.title,
      amountCents: item.amountCents,
      date: DateTime(current.year, current.month, day),
      category: item.category,
    );
    return state.copyWith(
      expenses: _sorted([...state.expenses, expense]),
      recurring: state.recurring
          .map((e) => e.id == id ? e.copyWith(lastApplied: current) : e)
          .toList(),
    );
  }

  ExpenseState _dueRecurring(ExpenseState state) {
    final current = now;
    for (final item in state.recurring) {
      final applied = item.lastApplied;
      if (applied != null &&
          applied.year * 100 + applied.month >=
              current.year * 100 + current.month) {
        continue;
      }
      final day = item.dayOfMonth.clamp(
        1,
        DateTime(current.year, current.month + 1, 0).day,
      );
      if (day > current.day) continue;
      state = _applyRecurring(state, item.id);
    }
    return state;
  }

  Future<bool> reconcileRecurring() =>
      _mutate((s) => s.autoApplyRecurring ? _dueRecurring(s) : s);

  String exportState() => _state.encode();
  String exportCsv() =>
      ExpenseCsv.encode(_state.expenses.map((e) => e.toMap()).toList());
  ExpenseState previewBackup(String source) => ExpenseState.decode(source);
  List<Expense> previewCsv(String source) {
    final rows = ExpenseCsv.decode(source);
    if (rows.isEmpty) throw const FormatException('CSV contains no expenses.');
    final ids = <String>{};
    return rows.map((row) {
      final e = Expense.fromMap(row);
      if (!ids.add(e.id)) {
        throw const FormatException('CSV contains duplicate IDs.');
      }
      return e;
    }).toList();
  }

  Future<bool> importState(String source) => _mutate(
    (s) => previewBackup(source).copyWith(requireBiometric: s.requireBiometric),
    recovery: true,
    allowRecovery: true,
  );
  Future<bool> importCsv(String source) => _mutate(
    (s) => s.copyWith(expenses: _sorted(previewCsv(source))),
    recovery: true,
    allowRecovery: true,
  );
  Future<String?> recoveryBackup() => _repository.readRecovery();
  Future<bool> resetStorage() =>
      _mutate((_) => const ExpenseState(), allowRecovery: true, reset: true);

  Future<bool> _mutate(
    ExpenseState Function(ExpenseState) change, {
    bool recovery = false,
    bool allowRecovery = false,
    bool reset = false,
  }) async {
    await initialized;
    final completer = Completer<bool>();
    _queue = _queue.then((_) async {
      _isSaving = true;
      _errorMessage = null;
      _notify();
      try {
        if (_loadFailed && !allowRecovery) {
          throw const FormatException(
            'Saved data could not be opened. Restore a valid backup or reset before making changes.',
          );
        }
        var next = change(_state);
        if (identical(next, _state)) {
          completer.complete(true);
          return;
        }
        // Alert delivery is independent of persistence; its deduplication marker
        // is saved with the expense so a platform error cannot invite retries.
        final period = now.year * 100 + now.month;
        final previousLevel = _state.budgetAlertPeriod == period
            ? _state.lastBudgetAlertLevel
            : 0;
        final ratio = next.budgetCents <= 0
            ? 0.0
            : _monthlyTotal(next) / next.budgetCents * 100;
        final level = ratio >= 120
            ? 120
            : ratio >= 100
            ? 100
            : ratio >= 80
            ? 80
            : 0;
        next = next.copyWith(
          budgetAlertPeriod: period,
          lastBudgetAlertLevel: reset
              ? 0
              : (level > previousLevel ? level : previousLevel),
        );
        final oldSource = recovery
            ? (await _repository.read() ?? exportState())
            : null;
        await _repository.write(
          next.encode(),
          recovery: oldSource,
          reset: reset,
        );
        _state = next;
        _loadFailed = false;
        _warningMessage = null;
        if (reset) {
          _timeFilter = 'Month';
          _customRangeStart = null;
          _customRangeEnd = null;
        }
        if (!reset && level > previousLevel) {
          try {
            await _budgetAlert(level);
          } catch (_) {
            /* Financial state is already committed. */
          }
        }
        completer.complete(true);
      } catch (error) {
        _errorMessage = error is FormatException
            ? error.message.toString()
            : 'Changes could not be saved. Your previous data is unchanged.';
        completer.complete(false);
      } finally {
        _isSaving = false;
        _notify();
      }
    });
    return completer.future;
  }

  Future<void> _loadData() async {
    try {
      final source = await _repository.read();
      if (source != null) {
        _state = ExpenseState.decode(source);
      } else {
        final legacy = await _repository.readLegacy();
        final expenses = <Expense>[];
        final rows = legacy['expenses'];
        var damaged = 0;
        if (rows is List) {
          for (final row in rows) {
            try {
              expenses.add(Expense.fromJson(row as String));
            } catch (_) {
              damaged++;
            }
          }
        }
        final rate = legacy['exchangeRate'];
        final budget = legacy['monthlyBudget'];
        _state = ExpenseState(
          expenses: _sorted(expenses),
          isUSD: legacy['isUSD'] is bool ? legacy['isUSD'] as bool : true,
          exchangeRate:
              rate is num && rate.isFinite && rate > 0 && rate <= 1000000
              ? rate.toDouble()
              : 540,
          budgetCents:
              budget is num &&
                  budget.isFinite &&
                  budget >= 0 &&
                  budget <= 9007199254740991 / 100
              ? (budget * 100).round()
              : 50000,
        );
        if (damaged > 0) {
          _warningMessage =
              '${damaged == 1 ? 'One' : damaged} damaged ${damaged == 1 ? 'expense was' : 'expenses were'} skipped while loading. Original storage is preserved; restore a complete backup before making changes.';
          _loadFailed = true;
        }
      }
      if (!_loadFailed) {
        // Complete migration only after the entire state has validated.
        final next = _state.autoApplyRecurring ? _dueRecurring(_state) : _state;
        await _repository.write(next.encode());
        _state = next;
      }
    } catch (_) {
      _loadFailed = true;
      _errorMessage =
          'Saved data could not be opened. No existing records were changed. Restore a backup or reset in Settings.';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  static DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);
  static List<Expense> _sorted(List<Expense> expenses) =>
      expenses..sort((a, b) => b.date.compareTo(a.date));
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
