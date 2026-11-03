import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/recurring_expense.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../utils/expense_categories.dart';
import '../widgets/app_sheet.dart';

class RecurringSheet extends StatefulWidget {
  const RecurringSheet({super.key});

  @override
  State<RecurringSheet> createState() => _RecurringSheetState();
}

class _RecurringSheetState extends State<RecurringSheet> {
  Future<void> _saveTemplate([RecurringExpense? existing]) async {
    final provider = context.read<ExpenseProvider>();
    final item = await showDialog<RecurringExpense>(
      context: context,
      builder: (_) => _RecurringEditor(
        isUSD: provider.isUSD,
        rate: provider.exchangeRate,
        initial: existing,
      ),
    );
    if (item == null || !mounted) return;
    final saved = existing == null
        ? await provider.addRecurring(item)
        : await provider.updateRecurring(item);
    if (!saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ??
                'Recurring transaction could not be saved.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    return AppSheet(
      title: 'Recurring transactions',
      subtitle: 'Monthly spending and income, added once per month.',
      closeLabel: 'Close recurring transactions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-add due transactions'),
            value: provider.autoApplyRecurring,
            subtitle: const Text(
              'Adds due templates for the current month. Missed months are not backfilled.',
            ),
            onChanged: provider.isSaving
                ? null
                : (value) => provider.setAutoApplyRecurring(value),
          ),
          FilledButton.icon(
            onPressed: provider.isSaving ? null : () => _saveTemplate(),
            icon: const Icon(Icons.add),
            label: const Text('Add recurring transaction'),
          ),
          const SizedBox(height: AppSpacing.md),
          if (provider.recurringExpenses.isEmpty)
            Text(
              'No recurring transactions yet.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            )
          else
            ...provider.recurringExpenses.map((item) {
              final applied =
                  item.lastApplied != null &&
                  item.lastApplied!.year == provider.now.year &&
                  item.lastApplied!.month == provider.now.month;
              final amount = CurrencyFormatter.displayFromUsdCents(
                usdCents: item.amountCents,
                isUsd: provider.isUSD,
                exchangeRate: provider.exchangeRate,
              );
              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${item.isIncome ? 'Received' : 'Spent'} · ${item.category} · day ${item.dayOfMonth} · $amount',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit ${item.title}',
                      onPressed: provider.isSaving
                          ? null
                          : () => _saveTemplate(item),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: applied
                          ? 'Applied this month'
                          : 'Apply this month',
                      onPressed: applied || provider.isSaving
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final ok = await provider.applyRecurring(item.id);
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? 'Recurring transaction applied.'
                                        : (provider.errorMessage ??
                                              'Could not apply recurring transaction.'),
                                  ),
                                ),
                              );
                            },
                      icon: Icon(
                        applied
                            ? Icons.check_circle_outline
                            : Icons.play_arrow_outlined,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      onPressed: provider.isSaving
                          ? null
                          : () async {
                              await provider.removeRecurring(item.id);
                              if (mounted) setState(() {});
                            },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _RecurringEditor extends StatefulWidget {
  const _RecurringEditor({
    required this.isUSD,
    required this.rate,
    this.initial,
  });
  final bool isUSD;
  final double rate;
  final RecurringExpense? initial;
  @override
  State<_RecurringEditor> createState() => _RecurringEditorState();
}

class _RecurringEditorState extends State<_RecurringEditor> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _day = TextEditingController(text: '1');
  String _category = 'Other';
  String _type = 'expense';
  String? _initialAmountText;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) return;
    _title.text = initial.title;
    _type = initial.type;
    _category = initial.category;
    _day.text = initial.dayOfMonth.toString();
    final value = widget.isUSD
        ? initial.amountCents / 100
        : initial.amountCents / 100 * widget.rate;
    _amount.text = value.toStringAsFixed(2);
    _initialAmountText = _amount.text;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _day.dispose();
    super.dispose();
  }

  int _amountCents() {
    if (widget.initial != null && _amount.text == _initialAmountText) {
      return widget.initial!.amountCents;
    }
    return Expense.fromEnteredAmount(
      id: widget.initial?.id ?? 'preview',
      title: _title.text.trim(),
      enteredAmount: CurrencyFormatter.parseAmount(_amount.text)!,
      currency: widget.isUSD ? 'USD' : 'YER',
      exchangeRate: widget.rate,
      date: DateTime.now(),
      category: _category,
      type: _type,
    ).amountCents;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.initial == null
          ? 'Add recurring transaction'
          : 'Edit recurring transaction',
    ),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Spent')),
                ButtonSegment(value: 'income', label: Text('Received')),
              ],
              selected: {_type},
              onSelectionChanged: (selection) => setState(() {
                _type = selection.first;
                _category = _type == 'income' ? 'Income' : 'Other';
              }),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _title,
              decoration: InputDecoration(
                labelText: _type == 'income' ? 'Source' : 'Title',
              ),
              maxLength: 80,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a transaction name.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Amount',
                suffixText: widget.isUSD ? 'USD' : 'YER',
              ),
              validator: (value) {
                final amount = CurrencyFormatter.parseAmount(value ?? '');
                if (amount == null || amount <= 0) {
                  return 'Enter a positive amount.';
                }
                if (widget.initial != null && value == _initialAmountText) {
                  return null;
                }
                try {
                  Expense.fromEnteredAmount(
                    id: 'validate',
                    title: 'Amount',
                    enteredAmount: amount,
                    currency: widget.isUSD ? 'USD' : 'YER',
                    exchangeRate: widget.rate,
                    date: DateTime.now(),
                    category: _category,
                  );
                } catch (_) {
                  return 'Amount must convert to at least 0.01 USD and fit safely.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              key: ValueKey('recurring-category-$_type-$_category'),
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items:
                  (_type == 'income'
                          ? {
                              'Income',
                              'Salary',
                              'Gift',
                              'Refund',
                              'Other',
                              _category,
                            }
                          : {...ExpenseCategory.labels, _category})
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
              onChanged: (value) {
                if (value != null) _category = value;
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _day,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Day of month',
                helperText: 'Days 29–31 use month end in shorter months.',
              ),
              validator: (value) {
                final day = int.tryParse(value ?? '');
                return day == null || day < 1 || day > 31
                    ? 'Choose a day from 1 to 31.'
                    : null;
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(
            context,
            RecurringExpense(
              id: widget.initial?.id ?? const Uuid().v4(),
              title: _title.text.trim(),
              amountCents: _amountCents(),
              category: _category,
              dayOfMonth: int.parse(_day.text),
              type: _type,
              lastApplied: widget.initial?.lastApplied,
            ),
          );
        },
        child: const Text('Save'),
      ),
    ],
  );
}
