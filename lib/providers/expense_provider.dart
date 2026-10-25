import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense.dart';

class ExpenseRemoval {
  const ExpenseRemoval({required this.expense, required this.index});

  final Expense expense;
  final int index;
}

class ExpenseProvider with ChangeNotifier {
  static const _stateKey = 'judgy_state_v2';
  static const _stateVersion = 2;
  static const _validFilters = {'Day', 'Week', 'Month'};
  static const _defaultExchangeRate = 540.0;
  static const _maxExchangeRate = 1000000.0;
  static const _defaultBudgetCents = 50000;
  static const _maxSafeJsonInteger = 9007199254740991;

  ExpenseProvider({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _initialized = _loadData();
  }

  final DateTime Function() _clock;
  final List<Expense> _expenses = [];
  Future<void> _mutationQueue = Future<void>.value();
  late final Future<void> _initialized;
  SharedPreferences? _preferences;

  bool _isUSD = true;
  double _exchangeRate = _defaultExchangeRate;
  int _monthlyBudgetCents = _defaultBudgetCents;
  String _timeFilter = 'Month';
  bool _isLoading = true;
  bool _isSaving = false;
  String? _warningMessage;
  String? _errorMessage;
  bool _loadFailed = false;

  UnmodifiableListView<Expense> get expenses => UnmodifiableListView(_expenses);
  DateTime get now => _clock();
  bool get isUSD => _isUSD;
  double get exchangeRate => _exchangeRate;
  int get monthlyBudgetCents => _monthlyBudgetCents;
  double get monthlyBudget => _monthlyBudgetCents / 100;
  String get timeFilter => _timeFilter;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get warningMessage => _warningMessage;
  String? get errorMessage => _errorMessage;
  bool get loadFailed => _loadFailed;
  Future<void> get initialized => _initialized;

  List<Expense> get filteredExpenses {
    final now = _clock();
    final start = switch (_timeFilter) {
      'Day' => _startOfDay(now),
      'Week' => _startOfWeek(now),
      _ => DateTime(now.year, now.month),
    };

    return _expenses
        .where(
          (expense) =>
              !expense.date.isBefore(start) && !expense.date.isAfter(now),
        )
        .toList(growable: false);
  }

  int get totalSpentCents =>
      filteredExpenses.fold(0, (total, expense) => total + expense.amountCents);

  int get monthlySpentCents {
    final now = _clock();
    final start = DateTime(now.year, now.month);
    return _expenses
        .where(
          (expense) =>
              !expense.date.isBefore(start) && !expense.date.isAfter(now),
        )
        .fold(0, (total, expense) => total + expense.amountCents);
  }

  int get monthlyRemainingCents => _monthlyBudgetCents - monthlySpentCents;

  double get budgetProgress {
    if (_monthlyBudgetCents <= 0) return 0;
    return (monthlySpentCents / _monthlyBudgetCents).clamp(0.0, 1.0);
  }

  bool get isOverBudget => monthlySpentCents > _monthlyBudgetCents;

  void setTimeFilter(String filter) {
    if (!_validFilters.contains(filter) || _timeFilter == filter) return;
    _timeFilter = filter;
    notifyListeners();
  }

  Future<bool> toggleCurrency() {
    return _commit(
      apply: () => _isUSD = !_isUSD,
      rollback: () => _isUSD = !_isUSD,
      failureMessage: 'Currency preference could not be saved.',
    );
  }

  Future<bool> updateSettings(double rate, double budget) {
    if (!rate.isFinite || rate <= 0 || rate > _maxExchangeRate || !budget.isFinite || budget < 0) {
      _setError('Enter a valid exchange rate and a budget of zero or more.');
      return Future.value(false);
    }

    if (budget > _maxSafeJsonInteger / 100) {
      _setError('That budget is too large to store safely.');
      return Future.value(false);
    }
    final budgetCents = (budget * 100).round();

    final previousRate = _exchangeRate;
    final previousBudget = _monthlyBudgetCents;
    return _commit(
      apply: () {
        _exchangeRate = rate;
        _monthlyBudgetCents = budgetCents;
      },
      rollback: () {
        _exchangeRate = previousRate;
        _monthlyBudgetCents = previousBudget;
      },
      failureMessage:
          'Settings could not be saved. Your previous values remain.',
    );
  }

  Future<bool> addExpense(Expense expense) {
    return _commit(
      apply: () {
        _expenses.add(expense);
        _expenses.sort((a, b) => b.date.compareTo(a.date));
      },
      rollback: () => _expenses.removeWhere((item) => item.id == expense.id),
      failureMessage: 'Expense could not be saved. Please try again.',
    );
  }

  Future<bool> updateExpense(Expense updated) {
    final previous = _expenses
        .where((expense) => expense.id == updated.id)
        .cast<Expense?>()
        .firstOrNull;
    if (previous == null) return Future.value(false);

    return _commit(
      apply: () {
        _expenses.removeWhere((expense) => expense.id == updated.id);
        _expenses.add(updated);
        _expenses.sort((a, b) => b.date.compareTo(a.date));
      },
      rollback: () {
        _expenses.removeWhere((expense) => expense.id == updated.id);
        _expenses.add(previous);
        _expenses.sort((a, b) => b.date.compareTo(a.date));
      },
      failureMessage: 'Expense could not be updated. Please try again.',
    );
  }

  Future<ExpenseRemoval?> removeExpense(String id) {
    return _enqueue(() async {
      final index = _expenses.indexWhere((expense) => expense.id == id);
      if (index < 0) return null;

      final removal = ExpenseRemoval(
        expense: _expenses.removeAt(index),
        index: index,
      );
      _beginSaving();
      try {
        await _saveState();
        return removal;
      } catch (_) {
        _expenses.insert(index.clamp(0, _expenses.length), removal.expense);
        _errorMessage = 'Expense could not be deleted. It has been restored.';
        return null;
      } finally {
        _finishSaving();
      }
    });
  }

  Future<bool> restoreExpense(ExpenseRemoval removal) {
    if (_expenses.any((expense) => expense.id == removal.expense.id)) {
      return Future.value(true);
    }

    var insertionIndex = 0;
    return _commit(
      apply: () {
        insertionIndex = removal.index.clamp(0, _expenses.length);
        _expenses.insert(insertionIndex, removal.expense);
      },
      rollback: () =>
          _expenses.removeWhere((item) => item.id == removal.expense.id),
      failureMessage: 'Expense could not be restored.',
    );
  }

  void clearWarning() {
    if (_warningMessage == null) return;
    _warningMessage = null;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// Explicitly discards the unreadable saved state so writes can resume.
  Future<void> resetStorage() async {
    _loadFailed = false;
    _expenses.clear();
    _warningMessage = null;
    _errorMessage = null;
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    _preferences = preferences;
    await preferences.remove(_stateKey);
    notifyListeners();
  }

  String exportState() {
    return jsonEncode(<String, dynamic>{
      'version': _stateVersion,
      'isUSD': _isUSD,
      'exchangeRate': _exchangeRate,
      'monthlyBudgetCents': _monthlyBudgetCents,
      'expenses': _expenses.map((expense) => expense.toMap()).toList(),
    });
  }

  Future<bool> importState(String source) {
    return _enqueue(() async {
      final decoded = jsonDecode(source);
      if (decoded is! Map) {
        throw const FormatException('Backup must contain an object.');
      }
      final state = Map<String, dynamic>.from(decoded);
      if (state['version'] != _stateVersion) {
        throw const FormatException('Unsupported backup version.');
      }

      final isUSD = state['isUSD'] is bool ? state['isUSD'] as bool : _isUSD;
      final exchangeRate = _validRate(state['exchangeRate']) ?? _exchangeRate;
      final monthlyBudgetCents =
          _validNonNegativeInteger(state['monthlyBudgetCents']) ??
          _monthlyBudgetCents;
      final importedExpenses = _parseExpenseRows(state['expenses']).toList();

      _isUSD = isUSD;
      _exchangeRate = exchangeRate;
      _monthlyBudgetCents = monthlyBudgetCents;
      _expenses
        ..clear()
        ..addAll(importedExpenses);
      _loadFailed = false;
      _warningMessage = null;
      _errorMessage = null;

      _beginSaving();
      try {
        await _saveState();
        return true;
      } finally {
        _finishSaving();
      }
    }).catchError((_) {
      _errorMessage = 'Backup could not be restored. Check the data and try again.';
      notifyListeners();
      return false;
    });
  }

  Future<bool> _commit({
    required VoidCallback apply,
    required VoidCallback rollback,
    required String failureMessage,
  }) {
    return _enqueue(() async {
      apply();
      _beginSaving();
      try {
        await _saveState();
        return true;
      } catch (_) {
        rollback();
        _errorMessage = failureMessage;
        return false;
      } finally {
        _finishSaving();
      }
    });
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _mutationQueue = _mutationQueue.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  void _beginSaving() {
    _errorMessage = null;
    _isSaving = true;
    notifyListeners();
  }

  void _finishSaving() {
    _isSaving = false;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  Future<void> _loadData() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _preferences = preferences;
      final stateJson = preferences.getString(_stateKey);
      if (stateJson != null) {
        _loadVersionedState(stateJson);
      } else {
        await _loadLegacyState(preferences);
      }
    } catch (_) {
      _loadFailed = true;
      _errorMessage =
          'Saved data could not be opened. No existing records were changed.';
    } finally {
      _expenses.sort((a, b) => b.date.compareTo(a.date));
      _isLoading = false;
      notifyListeners();
    }
  }

  void _loadVersionedState(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Saved state must contain an object.');
    }
    final state = Map<String, dynamic>.from(decoded);
    if (state['version'] != _stateVersion) {
      throw const FormatException('Unsupported saved state version.');
    }

    _isUSD = state['isUSD'] is bool ? state['isUSD'] as bool : true;
    _exchangeRate = _validRate(state['exchangeRate']) ?? _defaultExchangeRate;
    _monthlyBudgetCents =
        _validNonNegativeInteger(state['monthlyBudgetCents']) ??
        _defaultBudgetCents;
    _expenses
      ..clear()
      ..addAll(_parseExpenseRows(state['expenses']));
  }

  Future<void> _loadLegacyState(SharedPreferences preferences) async {
    _isUSD = preferences.getBool('isUSD') ?? true;
    _exchangeRate =
        _validRate(preferences.getDouble('exchangeRate')) ??
        _defaultExchangeRate;
    final legacyBudget = preferences.getDouble('monthlyBudget');
    _monthlyBudgetCents =
        legacyBudget != null &&
            legacyBudget.isFinite &&
            legacyBudget >= 0 &&
            legacyBudget <= _maxSafeJsonInteger / 100
        ? (legacyBudget * 100).round()
        : _defaultBudgetCents;

    final legacyRows = preferences.getStringList('expenses') ?? const [];
    var skippedRows = 0;
    for (final row in legacyRows) {
      try {
        _expenses.add(Expense.fromJson(row));
      } catch (_) {
        skippedRows++;
      }
    }
    if (skippedRows > 0) {
      _warningMessage = _skippedRowsMessage(skippedRows);
    }

    try {
      await _saveState();
    } catch (_) {
      _warningMessage =
          'Your data was loaded, but the storage upgrade could not be saved.';
    }
  }

  Iterable<Expense> _parseExpenseRows(dynamic rawRows) sync* {
    if (rawRows is! List) return;
    var skippedRows = 0;
    for (final rawRow in rawRows) {
      try {
        if (rawRow is! Map) throw const FormatException();
        yield Expense.fromMap(Map<String, dynamic>.from(rawRow));
      } catch (_) {
        skippedRows++;
      }
    }
    if (skippedRows > 0) {
      _warningMessage = _skippedRowsMessage(skippedRows);
    }
  }

  Future<void> _saveState() async {
    if (_loadFailed) {
      throw StateError('Saved data could not be opened; writes are blocked.');
    }
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    _preferences = preferences;
    final state = <String, dynamic>{
      'version': _stateVersion,
      'isUSD': _isUSD,
      'exchangeRate': _exchangeRate,
      'monthlyBudgetCents': _monthlyBudgetCents,
      'expenses': _expenses.map((expense) => expense.toMap()).toList(),
    };
    final saved = await preferences.setString(_stateKey, jsonEncode(state));
    if (!saved) throw StateError('Shared preferences rejected the write.');
  }

  static DateTime _startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static DateTime _startOfWeek(DateTime value) {
    final day = _startOfDay(value);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static double? _validRate(dynamic value) {
    if (value is! num) return null;
    final result = value.toDouble();
    return result.isFinite && result > 0 ? result : null;
  }

  static int? _validNonNegativeInteger(dynamic value) {
    if (value is! num || !value.isFinite || value < 0) return null;
    final result = value.toDouble();
    if (result != result.truncateToDouble() || result > _maxSafeJsonInteger) {
      return null;
    }
    return result.toInt();
  }

  static String _skippedRowsMessage(int count) {
    return count == 1
        ? 'One damaged expense was skipped while loading your history.'
        : '$count damaged expenses were skipped while loading your history.';
  }
}
