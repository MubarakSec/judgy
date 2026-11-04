import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../utils/expense_categories.dart';

/// Current-month category totals, separated by transaction direction.
class CategoryBreakdown extends StatefulWidget {
  const CategoryBreakdown({super.key});

  @override
  State<CategoryBreakdown> createState() => _CategoryBreakdownState();
}

class _CategoryBreakdownState extends State<CategoryBreakdown> {
  String _type = 'expense';
  String? _category;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final palette = AppPalette.of(context);
    String money(int cents) => CurrencyFormatter.displayFromUsdCents(
      usdCents: cents,
      isUsd: provider.isUSD,
      exchangeRate: provider.exchangeRate,
    );
    final totals = provider.monthlyCategoryTotals(_type);
    final chartTotals = <String, int>{
      if (_type == 'expense')
        for (final name in provider.categoryBudgetCents.keys) name: 0,
      ...totals,
    };
    final names = <String>{
      ...provider.categoriesFor(_type).map((category) => category.label),
      ...totals.keys,
    }.toList()..sort();
    final selected = names.contains(_category) ? _category : null;
    final entries = chartTotals.entries.toList()
      ..sort((a, b) {
        final amount = b.value.compareTo(a.value);
        return amount != 0 ? amount : a.key.compareTo(b.key);
      });
    final visible = selected == null
        ? entries
        : [MapEntry(selected, totals[selected] ?? 0)];
    final sum = visible.fold<int>(0, (value, entry) => value + entry.value);
    final maxValue = entries.isEmpty ? 0 : entries.first.value;
    final count = provider.monthlyCategoryCount(_type, category: selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('By category', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'expense', label: Text('Spent')),
            ButtonSegment(value: 'income', label: Text('Received')),
          ],
          selected: {_type},
          onSelectionChanged: (value) => setState(() {
            _type = value.first;
            _category = null;
          }),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String?>(
          key: ValueKey('report-category-$_type-$selected'),
          initialValue: selected,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All categories'),
            ),
            for (final name in names)
              DropdownMenuItem<String?>(value: name, child: Text(name)),
          ],
          onChanged: (value) => setState(() => _category = value),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: palette.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected ?? 'All categories',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        money(sum),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: _type == 'income'
                                  ? palette.success
                                  : palette.textPrimary,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '$count ${count == 1 ? 'entry' : 'entries'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (visible.isEmpty)
          Text(
            _type == 'income'
                ? 'No income this month.'
                : 'No spending this month.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          for (final entry in visible) ...[
            Row(
              children: [
                Icon(
                  ExpenseCategory.iconForKey(
                    provider.findCategory(entry.key, _type)?.iconKey ?? 'other',
                  ),
                  size: 18,
                  color: palette.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    entry.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(money(entry.value)),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.small),
              child: LinearProgressIndicator(
                value: maxValue == 0 ? 0 : entry.value / maxValue,
                minHeight: 6,
                backgroundColor: palette.input,
                color: _type == 'income' ? palette.success : palette.accent,
              ),
            ),
            if (_type == 'expense') ...[
              if (provider.categoryBudgetCents[entry.key]
                  case final int limit) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  entry.value > limit
                      ? '${money(entry.value - limit)} over ${money(limit)} limit'
                      : '${money(limit - entry.value)} left of ${money(limit)} limit',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: entry.value > limit
                        ? palette.danger
                        : palette.textSecondary,
                  ),
                ),
              ],
            ],
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }
}
