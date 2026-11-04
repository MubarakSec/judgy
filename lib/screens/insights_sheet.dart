import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../widgets/category_breakdown.dart';
import '../widgets/app_sheet.dart';
import '../widgets/cash_flow_history_chart.dart';

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
          const CategoryBreakdown(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'All transactions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          _InsightRow(
            label: 'Spent this month',
            value: currency(provider.monthlySpentCents),
          ),
          _InsightRow(
            label: 'Received this month',
            value: currency(provider.monthlyIncomeCents),
            valueColor: AppPalette.of(context).success,
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
            valueColor: change > 0
                ? AppPalette.of(context).danger
                : AppPalette.of(context).success,
          ),
          _InsightRow(
            label: 'Daily average',
            value: currency(provider.dailyAverageCents),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Cash flow', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text('Last six months', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          CashFlowHistoryChart(
            months: provider.sixMonthCashFlow,
            isUsd: provider.isUSD,
            exchangeRate: provider.exchangeRate,
          ),
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
              buffer.writeln('Spent by category:');
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
              buffer.writeln('Received by category:');
              final received =
                  provider.monthlyCategoryTotals('income').entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
              for (final entry in received) {
                buffer.writeln('  ${entry.key}: ${currency(entry.value)}');
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppPalette.of(context).textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: valueColor ?? AppPalette.of(context).textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
