import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';

class TotalSpentCard extends StatelessWidget {
  const TotalSpentCard({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ExpenseProvider>();
    final palette = AppPalette.of(context);
    String money(int cents) => CurrencyFormatter.displayFromUsdCents(
      usdCents: cents,
      isUsd: p.isUSD,
      exchangeRate: p.exchangeRate,
    );
    final spent = p.totalSpentCents;
    final received = p.totalIncomeCents;
    final total = spent + received;
    final period = switch (p.timeFilter) {
      'Day' => 'TODAY',
      'Week' => 'THIS WEEK',
      'Custom' => 'SELECTED RANGE',
      _ => 'THIS MONTH',
    };
    return Semantics(
      container: true,
      label:
          '$period. Spent ${money(spent)}. Received ${money(received)}. '
          'Net ${money(p.netCents.abs())} ${p.netCents < 0 ? 'out' : 'in'}.',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(AppRadii.large),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                period,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.textSecondary,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _FlowAmount(
                      label: 'Spent',
                      amount: money(spent),
                      color: palette.accent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _FlowAmount(
                      label: 'Received',
                      amount: money(received),
                      color: palette.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: Row(
                  children: [
                    if (total == 0)
                      Expanded(
                        child: Container(height: 7, color: palette.input),
                      )
                    else ...[
                      if (spent > 0)
                        Expanded(
                          flex: spent,
                          child: Container(height: 7, color: palette.accent),
                        ),
                      if (received > 0)
                        Expanded(
                          flex: received,
                          child: Container(height: 7, color: palette.success),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlowAmount extends StatelessWidget {
  const _FlowAmount({
    required this.label,
    required this.amount,
    required this.color,
  });
  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xs),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          amount,
          maxLines: 1,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(letterSpacing: -0.8),
        ),
      ),
    ],
  );
}
