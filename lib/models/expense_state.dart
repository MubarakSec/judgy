import 'dart:convert';

import 'expense.dart';
import 'recurring_expense.dart';

/// The portable, versioned representation shared by storage and backups.
class ExpenseState {
  const ExpenseState({
    this.expenses = const [],
    this.recurring = const [],
    this.isUSD = true,
    this.exchangeRate = 540,
    this.budgetCents = 50000,
    this.autoApplyRecurring = false,
    this.requireBiometric = false,
    this.voiceLocale = '',
    this.voiceOnDevice = true,
    this.lastBudgetAlertLevel = 0,
    this.budgetAlertPeriod = 0,
  });

  final List<Expense> expenses;
  final List<RecurringExpense> recurring;
  final bool isUSD;
  final double exchangeRate;
  final int budgetCents;
  final bool autoApplyRecurring;
  final bool requireBiometric;
  final String voiceLocale;
  final bool voiceOnDevice;
  final int lastBudgetAlertLevel;
  final int budgetAlertPeriod;

  factory ExpenseState.decode(String source) {
    if (utf8.encode(source).length > 10 * 1024 * 1024) {
      throw const FormatException('Backup exceeds 10 MB.');
    }
    final raw = jsonDecode(source);
    if (raw is! Map || raw['version'] != 2 || raw['expenses'] is! List) {
      throw const FormatException('Expected a version 2 expense backup.');
    }
    final rate = raw['exchangeRate'];
    final budget = raw['monthlyBudgetCents'];
    if (raw['isUSD'] is! bool ||
        rate is! num ||
        !rate.isFinite ||
        rate <= 0 ||
        rate > 1000000 ||
        budget is! int ||
        budget < 0 ||
        budget > 9007199254740991) {
      throw const FormatException('Invalid currency or budget settings.');
    }
    final expenses = <Expense>[];
    final ids = <String>{};
    for (final row in raw['expenses'] as List) {
      if (row is! Map) throw const FormatException('Invalid expense row.');
      final expense = Expense.fromMap(Map<String, dynamic>.from(row));
      if (!ids.add(expense.id)) {
        throw const FormatException('Duplicate expense ID.');
      }
      expenses.add(expense);
    }
    expenses.sort((a, b) => b.date.compareTo(a.date));
    final recurring = <RecurringExpense>[];
    ids.clear();
    final recurringRows = raw['recurringExpenses'] ?? const [];
    if (recurringRows is! List) {
      throw const FormatException('Invalid recurring list.');
    }
    for (final row in recurringRows) {
      if (row is! Map) throw const FormatException('Invalid recurring row.');
      final item = RecurringExpense.fromMap(Map<String, dynamic>.from(row));
      item.validate();
      if (!ids.add(item.id)) {
        throw const FormatException('Duplicate recurring ID.');
      }
      recurring.add(item);
    }
    bool flag(String key, bool fallback) {
      if (!raw.containsKey(key)) return fallback;
      if (raw[key] is! bool) throw FormatException('Invalid $key.');
      return raw[key] as bool;
    }

    final locale = raw['voiceLocale'] ?? '';
    if (locale is! String || locale.length > 80) {
      throw const FormatException('Invalid speech language.');
    }
    return ExpenseState(
      expenses: List.unmodifiable(expenses),
      recurring: List.unmodifiable(recurring),
      isUSD: raw['isUSD'] as bool,
      exchangeRate: rate.toDouble(),
      budgetCents: budget,
      autoApplyRecurring: flag('autoApplyRecurring', false),
      requireBiometric: flag('requireBiometric', false),
      voiceLocale: locale,
      voiceOnDevice: flag('voiceOnDevice', true),
      lastBudgetAlertLevel: raw['lastBudgetAlertLevel'] is int
          ? raw['lastBudgetAlertLevel'] as int
          : 0,
      budgetAlertPeriod: raw['budgetAlertPeriod'] is int
          ? raw['budgetAlertPeriod'] as int
          : 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'version': 2,
    'isUSD': isUSD,
    'exchangeRate': exchangeRate,
    'monthlyBudgetCents': budgetCents,
    'expenses': expenses.map((e) => e.toMap()).toList(),
    'recurringExpenses': recurring.map((e) => e.toMap()).toList(),
    'autoApplyRecurring': autoApplyRecurring,
    'requireBiometric': requireBiometric,
    'voiceLocale': voiceLocale,
    'voiceOnDevice': voiceOnDevice,
    'lastBudgetAlertLevel': lastBudgetAlertLevel,
    'budgetAlertPeriod': budgetAlertPeriod,
  };

  String encode() => jsonEncode(toMap());

  ExpenseState copyWith({
    List<Expense>? expenses,
    List<RecurringExpense>? recurring,
    bool? isUSD,
    double? exchangeRate,
    int? budgetCents,
    bool? autoApplyRecurring,
    bool? requireBiometric,
    String? voiceLocale,
    bool? voiceOnDevice,
    int? lastBudgetAlertLevel,
    int? budgetAlertPeriod,
  }) => ExpenseState(
    expenses: expenses == null ? this.expenses : List.unmodifiable(expenses),
    recurring: recurring == null
        ? this.recurring
        : List.unmodifiable(recurring),
    isUSD: isUSD ?? this.isUSD,
    exchangeRate: exchangeRate ?? this.exchangeRate,
    budgetCents: budgetCents ?? this.budgetCents,
    autoApplyRecurring: autoApplyRecurring ?? this.autoApplyRecurring,
    requireBiometric: requireBiometric ?? this.requireBiometric,
    voiceLocale: voiceLocale ?? this.voiceLocale,
    voiceOnDevice: voiceOnDevice ?? this.voiceOnDevice,
    lastBudgetAlertLevel: lastBudgetAlertLevel ?? this.lastBudgetAlertLevel,
    budgetAlertPeriod: budgetAlertPeriod ?? this.budgetAlertPeriod,
  );
}
