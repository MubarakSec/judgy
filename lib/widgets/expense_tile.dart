import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../screens/add_expense_sheet.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../utils/expense_categories.dart';

enum _ExpenseAction { edit, duplicate, pin, delete }

class ExpenseTile extends StatelessWidget {
  const ExpenseTile({super.key, required this.expense});

  final Expense expense;

  IconData _categoryIcon(ExpenseProvider provider) =>
      ExpenseCategory.iconForKey(
        provider.findCategory(expense.category, expense.type)?.iconKey ??
            'other',
      );

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

    HapticFeedback.lightImpact();
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
      barrierLabel: 'Close edit transaction',
      builder: (_) => AddExpenseSheet(expense: expense),
    );
    if (updated == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transaction updated.')));
    }
  }

  Future<void> _duplicate(BuildContext context) async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierLabel: 'Close duplicate transaction',
      builder: (_) => AddExpenseSheet(expense: expense, duplicate: true),
    );
    if (message == null || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _togglePin(
    BuildContext context,
    ExpenseProvider provider,
    bool wasPinned,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await provider.toggleQuickEntryPin(expense.id);
    if (!messenger.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? wasPinned
                    ? 'Removed from quick add.'
                    : 'Pinned to quick add.'
              : provider.errorMessage ?? 'Quick entry could not be changed.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ExpenseProvider>();
    final pinned = context.select<ExpenseProvider, bool>(
      (p) => p.isQuickEntryPinned(expense.id),
    );
    final isUSD = context.select<ExpenseProvider, bool>((p) => p.isUSD);
    final exchangeRate = context.select<ExpenseProvider, double>(
      (p) => p.exchangeRate,
    );
    final amount = CurrencyFormatter.displayFromUsdCents(
      usdCents: expense.amountCents,
      isUsd: isUSD,
      exchangeRate: exchangeRate,
    );
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(expense.date);
    final originalAmount =
        expense.originalAmountMinorUnits == null ||
            expense.originalCurrency == null ||
            (expense.originalCurrency == 'USD' && isUSD)
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
          color: AppPalette.of(context).danger,
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: AppPalette.of(context).onDanger),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Delete',
              style: TextStyle(
                color: AppPalette.of(context).onDanger,
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
            '${expense.isIncome ? 'Received' : 'Spent'}, ${expense.title}, ${expense.category}, $date, $amount'
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
            color: AppPalette.of(context).surface,
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppPalette.of(context).input,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    expense.isIncome
                        ? Icons.arrow_downward_rounded
                        : _categoryIcon(provider),
                    size: 21,
                    color: expense.isIncome
                        ? AppPalette.of(context).success
                        : AppPalette.of(context).textPrimary,
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
                          '${expense.isIncome ? '+' : '-'}$amount',
                          maxLines: 1,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: expense.isIncome
                                    ? AppPalette.of(context).success
                                    : null,
                              ),
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
                  } else if (action == _ExpenseAction.pin) {
                    _togglePin(context, provider, pinned);
                  } else if (action == _ExpenseAction.delete) {
                    _delete(context, provider);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: _ExpenseAction.edit,
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined),
                        SizedBox(width: AppSpacing.sm),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
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
                    value: _ExpenseAction.pin,
                    child: Row(
                      children: [
                        Icon(
                          pinned
                              ? Icons.push_pin_rounded
                              : Icons.push_pin_outlined,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            pinned ? 'Unpin quick entry' : 'Pin to quick add',
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _ExpenseAction.delete,
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          color: AppPalette.of(context).danger,
                        ),
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
