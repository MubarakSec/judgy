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
    final sortedCategories = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCategory = sortedCategories.isEmpty
        ? 1
        : sortedCategories.first.value;

    final change = provider.monthOverMonthChange;
    final changeLabel = change.isNaN
        ? '—'
        : '${change >= 0 ? '+' : ''}${(change * 100).toStringAsFixed(1)}%';

    return AppSheet(
      title: 'Insights',
      subtitle: 'Monthly totals, with change compared to the same elapsed period.',
      closeLabel: 'Close insights',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InsightRow(
            label: 'This month',
            value: currency(provider.monthlySpentCents),
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
              final ratio = maxCategory <= 0 ? 0.0 : entry.value / maxCategory;
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
                        Text(currency(entry.value)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.small),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        color: AppColors.accent,
                        backgroundColor: AppColors.input,
                      ),
                    ),
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
                'This month: ${currency(provider.monthlySpentCents)}',
              );
              buffer.writeln(
                'Previous month: ${currency(provider.previousMonthSpentCents)}',
              );
              buffer.writeln(
                'Daily average: ${currency(provider.dailyAverageCents)}',
              );
              buffer.writeln('Categories:');
              provider.categoryTotals.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value))
                ..forEach((entry) {
                  buffer.writeln('  ${entry.key}: ${currency(entry.value)}');
                });
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
