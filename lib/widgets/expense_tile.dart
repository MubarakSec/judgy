import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../screens/add_expense_sheet.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../utils/expense_categories.dart';

enum _ExpenseAction { edit, duplicate, delete }

class ExpenseTile extends StatelessWidget {
  const ExpenseTile({super.key, required this.expense});

  final Expense expense;

  IconData _categoryIcon(String category) => ExpenseCategory.iconFor(category);

  Future<void> _delete(BuildContext context, ExpenseProvider provider) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final removal = await provider.removeExpense(expense.id);
    if (!messenger.mounted) return;

    if (removal == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ?? 'Expense could not be deleted.',
          ),
        ),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text('${expense.title} deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            final restored = await provider.restoreExpense(removal);
            if (!restored && messenger.mounted) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    provider.errorMessage ?? 'Expense could not be restored.',
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierLabel: 'Close edit expense',
      builder: (_) => AddExpenseSheet(expense: expense),
    );
    if (updated == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense updated.')),
      );
    }
  }

  Future<void> _duplicate(BuildContext context) async {
    final quote = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierLabel: 'Close duplicate expense',
      builder: (_) => AddExpenseSheet(expense: expense, duplicate: true),
    );
    if (quote == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Duplicated. $quote')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final amount = CurrencyFormatter.displayFromUsdCents(
      usdCents: expense.amountCents,
      isUsd: provider.isUSD,
      exchangeRate: provider.exchangeRate,
    );
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(expense.date);
    final originalAmount =
        expense.originalAmountMinorUnits == null ||
            expense.originalCurrency == null ||
            (expense.originalCurrency == 'USD' && provider.isUSD)
        ? null
        : CurrencyFormatter.originalAmount(
            minorUnits: expense.originalAmountMinorUnits!,
            currency: expense.originalCurrency!,
          );

    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _delete(context, provider),
      background: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
        alignment: Alignment.centerRight,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: AppColors.onDanger),
            SizedBox(width: AppSpacing.xs),
            Text(
              'Delete',
              style: TextStyle(
                color: AppColors.onDanger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label:
            '${expense.title}, ${expense.category}, $date, $amount'
            '${originalAmount == null ? '' : ', entered $originalAmount'}',
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.medium),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: AppColors.input,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _categoryIcon(expense.category),
                    size: 21,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${expense.category} · $date',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (expense.note != null && expense.note!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          expense.note!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ExcludeSemantics(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '-$amount',
                          maxLines: 1,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (originalAmount != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          'Entered $originalAmount',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              PopupMenuButton<_ExpenseAction>(
                tooltip: 'More actions for ${expense.title}',
                icon: const Icon(Icons.more_vert),
                onSelected: (action) {
                  if (action == _ExpenseAction.edit) {
                    _edit(context);
                  } else if (action == _ExpenseAction.duplicate) {
                    _duplicate(context);
                  } else if (action == _ExpenseAction.delete) {
                    _delete(context, provider);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _ExpenseAction.edit,
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined),
                        SizedBox(width: AppSpacing.sm),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _ExpenseAction.duplicate,
                    child: Row(
                      children: [
                        Icon(Icons.copy_outlined),
                        SizedBox(width: AppSpacing.sm),
                        Text('Duplicate'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _ExpenseAction.delete,
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: AppColors.danger),
                        SizedBox(width: AppSpacing.sm),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
