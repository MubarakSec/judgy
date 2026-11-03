import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';

class QuickEntryStrip extends StatelessWidget {
  const QuickEntryStrip({super.key, required this.onSelected, this.selectedId});

  final ValueChanged<Expense> onSelected;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final entries = provider.quickEntries;
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Use again', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final pinned = provider.isQuickEntryPinned(entry.id);
              final selected = selectedId == entry.id;
              final amount =
                  entry.originalAmountMinorUnits != null &&
                      entry.originalCurrency != null
                  ? CurrencyFormatter.originalAmount(
                      minorUnits: entry.originalAmountMinorUnits!,
                      currency: entry.originalCurrency!,
                    )
                  : CurrencyFormatter.usdFromCents(entry.amountCents);
              return Semantics(
                button: true,
                label:
                    '${pinned ? 'Pinned, ' : ''}${entry.isIncome ? 'Received' : 'Spent'}, ${entry.title}, $amount',
                child: Material(
                  color: selected
                      ? AppColors.accentSoft
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                  child: InkWell(
                    key: ValueKey('quick-entry-${entry.id}'),
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                    onTap: () => onSelected(entry),
                    child: Container(
                      width: 148,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selected ? AppColors.accent : AppColors.border,
                        ),
                        borderRadius: BorderRadius.circular(AppRadii.medium),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              if (pinned)
                                const Icon(
                                  Icons.push_pin_rounded,
                                  size: 15,
                                  color: AppColors.accent,
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            amount,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
