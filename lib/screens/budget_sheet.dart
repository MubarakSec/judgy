import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../widgets/app_sheet.dart';
import 'category_budget_editor.dart';

class BudgetSheet extends StatelessWidget {
  const BudgetSheet({super.key});

  Future<void> _edit(BuildContext context, ExpenseProvider provider) async {
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => _BudgetEditor(initial: provider.monthlyBudget),
    );
    if (amount == null || !context.mounted) return;
    final saved = await provider.setMonthlyBudget(amount);
    if (!saved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Budget could not be saved.'),
        ),
      );
    }
  }

  Future<void> _editCategoryLimit(
    BuildContext context,
    ExpenseProvider provider, [
    String? existing,
  ]) async {
    final categories = <String>{
      ...provider.categoriesFor('expense').map((item) => item.label),
      ...provider.categoryBudgetCents.keys,
    }.toList()..sort();
    final available = existing == null
        ? categories
              .where((name) => !provider.categoryBudgetCents.containsKey(name))
              .toList()
        : categories;
    if (available.isEmpty) return;
    final change = await showDialog<CategoryBudgetChange>(
      context: context,
      builder: (_) => CategoryBudgetEditor(
        categories: available,
        isUsd: provider.isUSD,
        exchangeRate: provider.exchangeRate,
        initialCategory: existing,
        initialCents: existing == null
            ? null
            : provider.categoryBudgetCents[existing],
      ),
    );
    if (change == null || !context.mounted) return;
    final saved = await provider.setCategoryBudget(
      change.category,
      change.cents,
    );
    if (!saved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ?? 'Category limit could not be saved.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ExpenseProvider>();
    final palette = AppPalette.of(context);
    String money(int cents) => CurrencyFormatter.displayFromUsdCents(
      usdCents: cents,
      isUsd: p.isUSD,
      exchangeRate: p.exchangeRate,
    );
    final hasBudget = p.monthlyBudgetCents > 0;
    final left = p.monthlyRemainingCents;
    return AppSheet(
      title: 'Budget',
      closeLabel: 'Close budget',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: palette.surfaceElevated,
              borderRadius: BorderRadius.circular(AppRadii.large),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'THIS MONTH',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: palette.textSecondary,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  hasBudget ? money(left.abs()) : money(p.monthlySpentCents),
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                Text(
                  hasBudget
                      ? (left < 0 ? 'over budget' : 'remaining')
                      : 'spent',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: hasBudget ? p.budgetProgress : 0,
                    minHeight: 9,
                    backgroundColor: palette.input,
                    color: p.isOverBudget ? palette.danger : palette.accent,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  hasBudget
                      ? '${money(p.monthlySpentCents)} spent of ${money(p.monthlyBudgetCents)}'
                      : 'Set a monthly limit to track progress',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () => _edit(context, p),
            icon: const Icon(Icons.edit_outlined),
            label: Text(hasBudget ? 'Edit budget' : 'Set a budget'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Category limits',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (p.categoryBudgetCents.isEmpty)
            Text(
              'No category limits yet.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (p.categoryBudgetCents.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final entry in p.categoryBudgetCents.entries) ...[
              InkWell(
                onTap: () => _editCategoryLimit(context, p, entry.key),
                borderRadius: BorderRadius.circular(AppRadii.small),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.edit_outlined, size: 18),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${money(p.categoryTotals[entry.key] ?? 0)} spent of ${money(entry.value)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: ((p.categoryTotals[entry.key] ?? 0) / entry.value)
                      .clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: palette.input,
                  color: (p.categoryTotals[entry.key] ?? 0) > entry.value
                      ? palette.danger
                      : palette.accent,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
          OutlinedButton.icon(
            onPressed:
                p.isSaving ||
                    p.categoryBudgetCents.length >=
                        p.categoriesFor('expense').length
                ? null
                : () => _editCategoryLimit(context, p),
            icon: const Icon(Icons.add),
            label: const Text('Add category limit'),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _BudgetEditor extends StatefulWidget {
  const _BudgetEditor({required this.initial});
  final double initial;

  @override
  State<_BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends State<_BudgetEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initial.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Monthly budget'),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Limit',
          suffixText: 'USD',
          helperText: 'Zero turns off the limit',
        ),
        validator: (value) {
          final parsed = CurrencyFormatter.parseAmount(value ?? '');
          return parsed == null || parsed < 0 || parsed > 9007199254740991 / 100
              ? 'Enter a valid amount of zero or more.'
              : null;
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(
              context,
              CurrencyFormatter.parseAmount(_controller.text),
            );
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}
