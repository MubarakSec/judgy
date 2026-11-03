import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';

class TotalSpentCard extends StatelessWidget {
  const TotalSpentCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    String money(int cents) => CurrencyFormatter.displayFromUsdCents(
      usdCents: cents,
      isUsd: provider.isUSD,
      exchangeRate: provider.exchangeRate,
    );
    final spent = money(provider.totalSpentCents);
    final income = money(provider.totalIncomeCents);
    final net =
        '${provider.netCents < 0 ? '-' : '+'}${money(provider.netCents.abs())}';
    final hasBudget = provider.monthlyBudgetCents > 0;
    final remaining = money(provider.monthlyRemainingCents.abs());
    final periodLabel = switch (provider.timeFilter) {
      'Day' => 'Spent today',
      'Week' => 'Spent this week',
      'Custom' => 'Spent in range',
      _ => 'Spent this month',
    };

    return Semantics(
      container: true,
      label:
          '$periodLabel: $spent. Received: $income. Net: $net. '
          '${hasBudget ? 'Monthly budget: ${money(provider.monthlyBudgetCents)}. $remaining ${provider.isOverBudget ? 'over budget' : 'remaining'}.' : 'No monthly budget set.'}',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.large),
            border: provider.isOverBudget && hasBudget
                ? Border.all(color: AppColors.danger)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                periodLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  spent,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontSize: 36,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _Amount(
                      label: 'Received',
                      value: income,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _Amount(
                      label: 'Net',
                      value: net,
                      color: provider.netCents < 0
                          ? AppColors.danger
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Divider(height: 1, color: AppColors.border),
              const SizedBox(height: AppSpacing.sm),
              if (hasBudget) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Monthly budget',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      money(provider.monthlyBudgetCents),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.small),
                  child: LinearProgressIndicator(
                    value: provider.budgetProgress,
                    minHeight: 5,
                    color: provider.isOverBudget
                        ? AppColors.danger
                        : AppColors.accent,
                    backgroundColor: AppColors.input,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  provider.isOverBudget
                      ? '$remaining over budget'
                      : '$remaining left this month',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: provider.isOverBudget
                        ? AppColors.danger
                        : AppColors.textSecondary,
                  ),
                ),
              ] else
                Text(
                  'No monthly budget set',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: AppSpacing.xxs),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          maxLines: 1,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: color),
        ),
      ),
    ],
  );
}
