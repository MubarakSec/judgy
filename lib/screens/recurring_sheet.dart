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
  Future<void> _add() async {
    final provider = context.read<ExpenseProvider>();
    final item = await showDialog<RecurringExpense>(
      context: context,
      builder: (_) =>
          _RecurringEditor(isUSD: provider.isUSD, rate: provider.exchangeRate),
    );
    if (item == null || !mounted) return;
    final saved = await provider.addRecurring(item);
    if (!saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ?? 'Recurring expense could not be saved.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    return AppSheet(
      title: 'Recurring expenses',
      subtitle: 'Monthly spending you can apply once, or add automatically.',
      closeLabel: 'Close recurring expenses',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-apply due recurring expenses'),
            value: provider.autoApplyRecurring,
            subtitle: const Text(
              'Adds due templates for the current month. Missed months are not backfilled.',
            ),
            onChanged: provider.isSaving
                ? null
                : (value) => provider.setAutoApplyRecurring(value),
          ),
          FilledButton.icon(
            onPressed: provider.isSaving ? null : _add,
            icon: const Icon(Icons.add),
            label: const Text('Add recurring expense'),
          ),
          const SizedBox(height: AppSpacing.md),
          if (provider.recurringExpenses.isEmpty)
            Text(
              'No recurring expenses yet.',
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
                            '${item.category} · day ${item.dayOfMonth} · $amount',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
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
                                        ? 'Recurring expense applied.'
                                        : (provider.errorMessage ??
                                              'Could not apply recurring expense.'),
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
  const _RecurringEditor({required this.isUSD, required this.rate});
  final bool isUSD;
  final double rate;
  @override
  State<_RecurringEditor> createState() => _RecurringEditorState();
}

class _RecurringEditorState extends State<_RecurringEditor> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _day = TextEditingController(text: '1');
  String _category = 'Other';
  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _day.dispose();
    super.dispose();
  }

  Expense _entry() => Expense.fromEnteredAmount(
    id: const Uuid().v4(),
    title: _title.text.trim(),
    enteredAmount: CurrencyFormatter.parseAmount(_amount.text)!,
    currency: widget.isUSD ? 'USD' : 'YER',
    exchangeRate: widget.rate,
    date: DateTime.now(),
    category: _category,
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add recurring expense'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              maxLength: 80,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter an expense name.'
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
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: ExpenseCategory.labels
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
          final entry = _entry();
          Navigator.pop(
            context,
            RecurringExpense(
              id: entry.id,
              title: entry.title,
              amountCents: entry.amountCents,
              category: entry.category,
              dayOfMonth: int.parse(_day.text),
            ),
          );
        },
        child: const Text('Save'),
      ),
    ],
  );
}
