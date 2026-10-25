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
    final spent = CurrencyFormatter.displayFromUsdCents(
      usdCents: provider.totalSpentCents,
      isUsd: provider.isUSD,
      exchangeRate: provider.exchangeRate,
    );
    final budget = CurrencyFormatter.displayFromUsdCents(
      usdCents: provider.monthlyBudgetCents,
      isUsd: provider.isUSD,
      exchangeRate: provider.exchangeRate,
    );
    final remaining = CurrencyFormatter.displayFromUsdCents(
      usdCents: provider.monthlyRemainingCents.abs(),
      isUsd: provider.isUSD,
      exchangeRate: provider.exchangeRate,
    );
    final hasBudget = provider.monthlyBudgetCents > 0;
    final percentage = hasBudget
        ? (provider.monthlySpentCents / provider.monthlyBudgetCents * 100)
        : 0.0;
    final percentageLabel = percentage < 10 && percentage % 1 != 0
        ? percentage.toStringAsFixed(1)
        : percentage.round().toString();
    final periodLabel = switch (provider.timeFilter) {
      'Day' => 'Spent today',
      'Week' => 'Spent this week',
      _ => 'Spent this month',
    };

    return Semantics(
      container: true,
      label: hasBudget
          ? '$periodLabel: $spent. Monthly budget: $budget. '
                '${provider.isOverBudget ? '$remaining over budget' : '$remaining remaining'}. '
                '$percentageLabel% used.'
          : '$periodLabel: $spent. No monthly budget set.',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.large),
            border: Border.all(
              color: provider.isOverBudget && hasBudget
                  ? AppColors.danger
                  : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                periodLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    spent,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              if (!hasBudget)
                Row(
                  children: [
                    const Icon(
                      Icons.flag_outlined,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'No monthly budget set',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Monthly budget',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      budget,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.small),
                  child: LinearProgressIndicator(
                    value: provider.budgetProgress,
                    minHeight: 8,
                    color: provider.isOverBudget
                        ? AppColors.danger
                        : AppColors.accent,
                    backgroundColor: AppColors.input,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        provider.isOverBudget
                            ? '$remaining over budget'
                            : '$remaining remaining',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: provider.isOverBudget
                              ? AppColors.danger
                              : AppColors.textSecondary,
                          fontWeight: provider.isOverBudget
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '$percentageLabel%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: provider.isOverBudget
                            ? AppColors.danger
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (provider.timeFilter != 'Month') ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Budget progress always reflects the current month.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
