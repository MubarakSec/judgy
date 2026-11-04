import 'expense.dart';
import 'recurring_expense.dart';
import 'favorite_template.dart';

class LedgerCategory {
  const LedgerCategory({
    required this.label,
    required this.type,
    required this.iconKey,
  });

  final String label;
  final String type;
  final String iconKey;

  static const iconKeys = {
    'coffee',
    'food',
    'shopping',
    'subscriptions',
    'other',
    'transport',
    'home',
    'health',
    'work',
    'gift',
    'income',
    'education',
    'travel',
  };

  static const defaults = <LedgerCategory>[
    LedgerCategory(label: 'Coffee', type: 'expense', iconKey: 'coffee'),
    LedgerCategory(label: 'Food', type: 'expense', iconKey: 'food'),
    LedgerCategory(label: 'Shopping', type: 'expense', iconKey: 'shopping'),
    LedgerCategory(
      label: 'Subscriptions',
      type: 'expense',
      iconKey: 'subscriptions',
    ),
    LedgerCategory(label: 'Other', type: 'expense', iconKey: 'other'),
    LedgerCategory(label: 'Income', type: 'income', iconKey: 'income'),
    LedgerCategory(label: 'Salary', type: 'income', iconKey: 'work'),
    LedgerCategory(label: 'Gift', type: 'income', iconKey: 'gift'),
    LedgerCategory(label: 'Refund', type: 'income', iconKey: 'income'),
    LedgerCategory(label: 'Other', type: 'income', iconKey: 'other'),
  ];

  void validate() {
    if (label.isEmpty ||
        label != label.trim() ||
        label.length > 1000 ||
        (type != 'expense' && type != 'income') ||
        !iconKeys.contains(iconKey)) {
      throw const FormatException('Invalid category name, type, or icon.');
    }
  }

  Map<String, String> toMap() => {
    'label': label,
    'type': type,
    'iconKey': iconKey,
  };

  factory LedgerCategory.fromMap(Map<String, dynamic> map) {
    if (map['label'] is! String ||
        map['type'] is! String ||
        map['iconKey'] is! String) {
      throw const FormatException('Invalid category.');
    }
    final category = LedgerCategory(
      label: map['label'] as String,
      type: map['type'] as String,
      iconKey: map['iconKey'] as String,
    );
    category.validate();
    return category;
  }

  static List<LedgerCategory> includeUsed({
    required Iterable<LedgerCategory> categories,
    required Iterable<Expense> expenses,
    required Iterable<RecurringExpense> recurring,
    required Iterable<String> budgetCategories,
    Iterable<FavoriteTemplate> favorites = const [],
  }) {
    final result = [...categories];
    final seen = <String>{
      for (final category in result) '${category.type}|${category.label}',
    };
    void add(String label, String type) {
      if (label.trim().isEmpty) return;
      final key = '$type|$label';
      if (seen.add(key)) {
        result.add(
          LedgerCategory(
            label: label,
            type: type,
            iconKey: type == 'income' ? 'income' : 'other',
          ),
        );
      }
    }

    for (final expense in expenses) {
      add(expense.category, expense.type);
    }
    for (final item in recurring) {
      add(item.category, item.type);
    }
    for (final favorite in favorites) {
      add(favorite.category, favorite.type);
    }
    for (final category in budgetCategories) {
      add(category, 'expense');
    }
    return List.unmodifiable(result);
  }

  static void validateList(List<LedgerCategory> categories) {
    if (categories.length > 100) {
      throw const FormatException('Too many categories.');
    }
    final seen = <String>{};
    var spending = 0;
    var income = 0;
    for (final category in categories) {
      category.validate();
      if (!seen.add('${category.type}|${category.label}')) {
        throw const FormatException('Duplicate category.');
      }
      if (category.type == 'income') {
        income++;
      } else {
        spending++;
      }
    }
    if (spending == 0 || income == 0) {
      throw const FormatException('Keep at least one category for each type.');
    }
  }
}
