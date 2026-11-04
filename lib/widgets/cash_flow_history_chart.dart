import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/cash_flow_history.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';

class CashFlowHistoryChart extends StatefulWidget {
  const CashFlowHistoryChart({
    super.key,
    required this.months,
    required this.isUsd,
    required this.exchangeRate,
  });

  final List<MonthlyCashFlow> months;
  final bool isUsd;
  final double exchangeRate;

  @override
  State<CashFlowHistoryChart> createState() => _CashFlowHistoryChartState();
}

class _CashFlowHistoryChartState extends State<CashFlowHistoryChart> {
  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  int? _selectedIndex;

  String _money(int cents) => CurrencyFormatter.displayFromUsdCents(
    usdCents: cents,
    isUsd: widget.isUsd,
    exchangeRate: widget.exchangeRate,
  );

  @override
  Widget build(BuildContext context) {
    final months = widget.months;
    if (months.isEmpty || months.every((month) => month.isEmpty)) {
      return Text(
        'No transactions in the last six months.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppPalette.of(context).textSecondary,
        ),
      );
    }
    final selected = (_selectedIndex ?? months.length - 1).clamp(
      0,
      months.length - 1,
    );
    final largest = months.fold<int>(
      1,
      (maxValue, month) =>
          math.max(maxValue, math.max(month.spentCents, month.receivedCents)),
    );
    final current = months[selected];
    final net = current.netCents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Legend(color: AppPalette.of(context).accent, label: 'Spent'),
            const SizedBox(width: AppSpacing.md),
            _Legend(color: AppPalette.of(context).success, label: 'Received'),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 142,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < months.length; index++)
                Expanded(
                  child: _MonthBars(
                    month: months[index],
                    label: _monthNames[months[index].month.month - 1],
                    maxCents: largest,
                    selected: index == selected,
                    spent: _money(months[index].spentCents),
                    received: _money(months[index].receivedCents),
                    onTap: () => setState(() => _selectedIndex = index),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppPalette.of(context).surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_monthNames[current.month.month - 1]} ${current.month.year}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _MonthValue(
                      label: 'Spent',
                      value: _money(current.spentCents),
                    ),
                  ),
                  Expanded(
                    child: _MonthValue(
                      label: 'Received',
                      value: _money(current.receivedCents),
                      color: AppPalette.of(context).success,
                    ),
                  ),
                  Expanded(
                    child: _MonthValue(
                      label: 'Net',
                      value: '${net < 0 ? '-' : '+'}${_money(net.abs())}',
                      color: net < 0
                          ? AppPalette.of(context).danger
                          : AppPalette.of(context).textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthBars extends StatelessWidget {
  const _MonthBars({
    required this.month,
    required this.label,
    required this.maxCents,
    required this.selected,
    required this.spent,
    required this.received,
    required this.onTap,
  });

  final MonthlyCashFlow month;
  final String label;
  final int maxCents;
  final bool selected;
  final String spent;
  final String received;
  final VoidCallback onTap;

  Widget _bar(int cents, Color color) => SizedBox(
    width: 10,
    height: cents == 0 ? 0 : math.max(4, cents / maxCents * 90),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '$label ${month.month.year}: spent $spent, received $received',
    child: InkWell(
      key: ValueKey('cash-flow-${month.month.year}-${month.month.month}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.small),
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: selected
                ? AppPalette.of(context).surfaceElevated
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.small),
            border: Border.all(
              color: selected
                  ? AppPalette.of(context).border
                  : Colors.transparent,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _bar(month.spentCents, AppPalette.of(context).accent),
                      const SizedBox(width: 3),
                      _bar(month.receivedCents, AppPalette.of(context).success),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected
                      ? AppPalette.of(context).textPrimary
                      : AppPalette.of(context).textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: AppSpacing.xxs),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _MonthValue extends StatelessWidget {
  const _MonthValue({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

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
