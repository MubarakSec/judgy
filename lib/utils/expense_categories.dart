import 'package:flutter/material.dart';

/// Single source of truth for expense categories, their icons, and quotes.
class ExpenseCategory {
  const ExpenseCategory({
    required this.label,
    required this.icon,
    required this.quotes,
  });

  final String label;
  final IconData icon;
  final List<String> quotes;

  static const List<ExpenseCategory> all = <ExpenseCategory>[
    ExpenseCategory(
      label: 'Coffee',
      icon: Icons.coffee_outlined,
      quotes: <String>[
        "Another iced coffee? In this economy?",
        "You're single-handedly funding the barista's retirement.",
        "Just drink water, it's free.",
      ],
    ),
    ExpenseCategory(
      label: 'Food',
      icon: Icons.restaurant_outlined,
      quotes: <String>[
        "Cooking at home is a thing, you know.",
        "Your fridge is crying right now.",
        "Again? Really?",
      ],
    ),
    ExpenseCategory(
      label: 'Shopping',
      icon: Icons.shopping_bag_outlined,
      quotes: <String>[
        "Do you really need this, or are you just sad?",
        "Add to cart? More like add to debt.",
        "Your wallet is begging for mercy.",
      ],
    ),
    ExpenseCategory(
      label: 'Subscriptions',
      icon: Icons.subscriptions_outlined,
      quotes: <String>[
        "You don't even use this.",
        "Ah yes, paying monthly to ignore it daily.",
      ],
    ),
    ExpenseCategory(
      label: 'Other',
      icon: Icons.receipt_long_outlined,
      quotes: <String>[
        "Interesting financial decision.",
        "I'm not mad, I'm just disappointed.",
        "Is this why you're broke?",
      ],
    ),
  ];

  static List<String> get labels => all.map((category) => category.label).toList();

  static ExpenseCategory? byLabel(String label) {
    for (final category in all) {
      if (category.label == label) return category;
    }
    return null;
  }

  static IconData iconFor(String label) =>
      byLabel(label)?.icon ?? Icons.receipt_long_outlined;

  static List<String> quotesFor(String label) =>
      byLabel(label)?.quotes ?? all.last.quotes;
}
