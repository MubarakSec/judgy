import 'dart:math';

import 'expense_categories.dart';

class JudgyQuotes {
  static final Random _random = Random();

  static String getQuote(String category, double amount) {
    if (amount > 100) {
      return "Wow. Big spender. Must be nice.";
    }

    final categoryQuotes = ExpenseCategory.quotesFor(category);
    return categoryQuotes[_random.nextInt(categoryQuotes.length)];
  }
}
