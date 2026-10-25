import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/recurring_expense.dart';
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
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final dayController = TextEditingController(text: '1');
    String category = ExpenseCategory.labels.first;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add recurring expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    suffixText: provider.isUSD ? 'USD' : 'YER',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  items: ExpenseCategory.labels
                      .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) category = value;
                  },
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: dayController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Day of month'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved != true || !mounted) return;
    final amount = CurrencyFormatter.parseAmount(amountController.text);
    if (amount == null || amount <= 0) return;
    final day = int.tryParse(dayController.text.trim()) ?? 1;
    final usdCents = provider.isUSD
        ? (amount * 100).round()
        : (amount / provider.exchangeRate * 100).round();

    await provider.addRecurring(
      RecurringExpense(
        id: const Uuid().v4(),
        title: titleController.text.trim().isEmpty
            ? 'Recurring expense'
            : titleController.text.trim(),
        amountCents: usdCents,
        category: category,
        dayOfMonth: day.clamp(1, 31),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    return AppSheet(
      title: 'Recurring expenses',
      subtitle: 'Templates you can apply each month.',
      closeLabel: 'Close recurring expenses',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-apply due recurring expenses'),
            value: provider.autoApplyRecurring,
            onChanged: (value) => provider.setAutoApplyRecurring(value),
          ),
          FilledButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('Add recurring expense'),
          ),
          const SizedBox(height: AppSpacing.md),
          if (provider.recurringExpenses.isEmpty)
            Text(
              'No recurring expenses yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            )
          else
            ...provider.recurringExpenses.map((item) {
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
                          Text(item.title,
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(
                            '${item.category} · day ${item.dayOfMonth} · $amount',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Apply this month',
                      onPressed: () async {
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
                      icon: const Icon(Icons.play_arrow_outlined),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      onPressed: () async {
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
