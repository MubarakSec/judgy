import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';

class CategoryBudgetChange {
  const CategoryBudgetChange(this.category, this.cents);
  final String category;
  final int? cents;
}

class CategoryBudgetEditor extends StatefulWidget {
  const CategoryBudgetEditor({
    super.key,
    required this.categories,
    required this.isUsd,
    required this.exchangeRate,
    this.initialCategory,
    this.initialCents,
  });

  final List<String> categories;
  final bool isUsd;
  final double exchangeRate;
  final String? initialCategory;
  final int? initialCents;

  @override
  State<CategoryBudgetEditor> createState() => _CategoryBudgetEditorState();
}

class _CategoryBudgetEditorState extends State<CategoryBudgetEditor> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  late String _category;
  String? _initialAmountText;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory ?? widget.categories.first;
    final cents = widget.initialCents;
    if (cents != null) {
      final value = widget.isUsd
          ? cents / 100
          : cents / 100 * widget.exchangeRate;
      _amount.text = value.toStringAsFixed(2);
      _initialAmountText = _amount.text;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int _convert(double amount) => Expense.fromEnteredAmount(
    id: 'category-budget-preview',
    title: _category,
    enteredAmount: amount,
    currency: widget.isUsd ? 'USD' : 'YER',
    exchangeRate: widget.exchangeRate,
    date: DateTime(2000),
    category: _category,
  ).amountCents;

  void _save() {
    if (!_form.currentState!.validate()) return;
    final cents =
        widget.initialCents != null && _amount.text == _initialAmountText
        ? widget.initialCents!
        : _convert(CurrencyFormatter.parseAmount(_amount.text)!);
    Navigator.pop(context, CategoryBudgetChange(_category, cents));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.initialCategory == null
          ? 'Add category budget'
          : 'Edit category budget',
    ),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category'),
              items: widget.categories
                  .map(
                    (name) => DropdownMenuItem(value: name, child: Text(name)),
                  )
                  .toList(),
              onChanged: widget.initialCategory != null
                  ? null
                  : (value) {
                      if (value != null) setState(() => _category = value);
                    },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Monthly limit',
                suffixText: widget.isUsd ? 'USD' : 'YER',
                helperText: widget.isUsd
                    ? null
                    : 'Saved in USD at the current exchange rate.',
              ),
              validator: (value) {
                final amount = CurrencyFormatter.parseAmount(value ?? '');
                if (amount == null || amount <= 0) {
                  return 'Enter an amount above zero.';
                }
                if (widget.initialCents != null &&
                    value == _initialAmountText) {
                  return null;
                }
                try {
                  _convert(amount);
                } catch (_) {
                  return 'Enter an amount that converts to at least 0.01 USD.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      if (widget.initialCategory != null)
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            CategoryBudgetChange(widget.initialCategory!, null),
          ),
          child: const Text('Remove'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save')),
    ],
  );
}
