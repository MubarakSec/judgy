import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../utils/expense_categories.dart';
import '../widgets/app_sheet.dart';

class InsightsSheet extends StatelessWidget {
  const InsightsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    String currency(int cents) => CurrencyFormatter.displayFromUsdCents(
      usdCents: cents,
      isUsd: provider.isUSD,
      exchangeRate: provider.exchangeRate,
    );

    final totals = provider.categoryTotals;
    final sortedCategories =
        {...totals.keys, ...provider.categoryBudgetCents.keys}
            .map((category) => MapEntry(category, totals[category] ?? 0))
            .toList()
          ..sort((a, b) {
            final bySpent = b.value.compareTo(a.value);
            return bySpent == 0 ? a.key.compareTo(b.key) : bySpent;
          });
    final maxCategory = sortedCategories.isEmpty
        ? 1
        : sortedCategories.first.value;

    final change = provider.monthOverMonthChange;
    final changeLabel = change.isNaN
        ? '—'
        : '${change >= 0 ? '+' : ''}${(change * 100).toStringAsFixed(1)}%';

    return AppSheet(
      title: 'Insights',
      subtitle:
          'Monthly totals, with change compared to the same elapsed period.',
      closeLabel: 'Close insights',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InsightRow(
            label: 'Spent this month',
            value: currency(provider.monthlySpentCents),
          ),
          _InsightRow(
            label: 'Received this month',
            value: currency(provider.monthlyIncomeCents),
            valueColor: AppColors.success,
          ),
          _InsightRow(
            label: 'Net this month',
            value:
                '${provider.monthlyIncomeCents - provider.monthlySpentCents < 0 ? '-' : '+'}${currency((provider.monthlyIncomeCents - provider.monthlySpentCents).abs())}',
          ),
          _InsightRow(
            label: 'Previous month',
            value: currency(provider.previousMonthSpentCents),
          ),
          _InsightRow(
            label: 'Vs. same period last month',
            value: changeLabel,
            valueColor: change > 0 ? AppColors.danger : AppColors.success,
          ),
          _InsightRow(
            label: 'Daily average',
            value: currency(provider.dailyAverageCents),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Top categories',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (sortedCategories.isEmpty)
            Text(
              'No expenses this month yet.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            )
          else
            ...sortedCategories.map((entry) {
              final limit = provider.categoryBudgetCents[entry.key];
              final over = limit != null && entry.value > limit;
              final ratio = limit == null
                  ? (maxCategory <= 0 ? 0.0 : entry.value / maxCategory)
                  : (entry.value / limit).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          ExpenseCategory.iconFor(entry.key),
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(child: Text(entry.key)),
                        Text(
                          currency(entry.value),
                          style: over
                              ? const TextStyle(color: AppColors.danger)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.small),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        color: over ? AppColors.danger : AppColors.accent,
                        backgroundColor: AppColors.input,
                      ),
                    ),
                    if (limit != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        over
                            ? '${currency(entry.value - limit)} over ${currency(limit)} limit'
                            : '${currency(limit - entry.value)} left of ${currency(limit)} limit',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: over
                              ? AppColors.danger
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: () {
              final provider = context.read<ExpenseProvider>();
              String currency(int cents) =>
                  CurrencyFormatter.displayFromUsdCents(
                    usdCents: cents,
                    isUsd: provider.isUSD,
                    exchangeRate: provider.exchangeRate,
                  );
              final buffer = StringBuffer();
              buffer.writeln('Judgy monthly summary');
              buffer.writeln(
                'Spent this month: ${currency(provider.monthlySpentCents)}',
              );
              buffer.writeln(
                'Received this month: ${currency(provider.monthlyIncomeCents)}',
              );
              buffer.writeln(
                'Previous month: ${currency(provider.previousMonthSpentCents)}',
              );
              buffer.writeln(
                'Daily average: ${currency(provider.dailyAverageCents)}',
              );
              buffer.writeln('Categories:');
              final categories =
                  {
                        ...provider.categoryTotals.keys,
                        ...provider.categoryBudgetCents.keys,
                      }
                      .map(
                        (category) => MapEntry(
                          category,
                          provider.categoryTotals[category] ?? 0,
                        ),
                      )
                      .toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
              for (final entry in categories) {
                final limit = provider.categoryBudgetCents[entry.key];
                buffer.writeln(
                  '  ${entry.key}: ${currency(entry.value)}${limit == null ? '' : ' of ${currency(limit)} limit'}',
                );
              }
              Clipboard.setData(ClipboardData(text: buffer.toString()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Monthly summary copied.')),
              );
            },
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('Copy monthly summary'),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
