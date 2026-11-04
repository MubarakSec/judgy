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

  static const icons = <String, IconData>{
    'coffee': Icons.coffee_outlined,
    'food': Icons.restaurant_outlined,
    'shopping': Icons.shopping_bag_outlined,
    'subscriptions': Icons.subscriptions_outlined,
    'other': Icons.receipt_long_outlined,
    'transport': Icons.directions_bus_outlined,
    'home': Icons.home_outlined,
    'health': Icons.health_and_safety_outlined,
    'work': Icons.work_outline,
    'gift': Icons.card_giftcard_outlined,
    'income': Icons.south_west_rounded,
    'education': Icons.school_outlined,
    'travel': Icons.flight_outlined,
  };

  static IconData iconForKey(String key) =>
      icons[key] ?? Icons.receipt_long_outlined;

  static IconData iconFor(String label) {
    for (final category in all) {
      if (category.label == label) return category.icon;
    }
    return Icons.receipt_long_outlined;
  }
}
