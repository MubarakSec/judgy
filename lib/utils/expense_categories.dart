import 'package:flutter/material.dart';

class ExpenseCategory {
  const ExpenseCategory({required this.label, required this.icon});

  final String label;
  final IconData icon;

  static const all = <ExpenseCategory>[
    ExpenseCategory(label: 'Coffee', icon: Icons.coffee_outlined),
    ExpenseCategory(label: 'Food', icon: Icons.restaurant_outlined),
    ExpenseCategory(label: 'Shopping', icon: Icons.shopping_bag_outlined),
    ExpenseCategory(label: 'Subscriptions', icon: Icons.subscriptions_outlined),
    ExpenseCategory(label: 'Other', icon: Icons.receipt_long_outlined),
  ];

  static List<String> get labels =>
      all.map((category) => category.label).toList();

  static IconData iconFor(String label) {
    for (final category in all) {
      if (category.label == label) return category.icon;
    }
    return Icons.receipt_long_outlined;
  }
}
