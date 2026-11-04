import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/expense.dart';
import '../models/favorite_template.dart';
import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';

class QuickEntryStrip extends StatelessWidget {
  const QuickEntryStrip({
    super.key,
    required this.onSelected,
    required this.onFavoriteSelected,
    required this.onAddFavorite,
    required this.onManageFavorites,
    this.selectedId,
    this.selectedFavoriteId,
  });

  final ValueChanged<Expense> onSelected;
  final ValueChanged<FavoriteTemplate> onFavoriteSelected;
  final VoidCallback onAddFavorite;
  final VoidCallback onManageFavorites;
  final String? selectedId;
  final String? selectedFavoriteId;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ExpenseProvider>();
    final favorites = p.favorites;
    final favoriteKeys = {
      for (final item in favorites)
        '${item.type}|${item.title.trim().toLowerCase()}|${item.category}',
    };
    final recent = p.quickEntries
        .where(
          (item) => !favoriteKeys.contains(
            '${item.type}|${item.title.trim().toLowerCase()}|${item.category}',
          ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Quick picks',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: onManageFavorites,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount:
                favorites.length +
                recent.length +
                (favorites.length < 12 ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
            itemBuilder: (context, index) {
              if (index < favorites.length) {
                final item = favorites[index];
                return _PickCard(
                  key: ValueKey('favorite-${item.id}'),
                  title: item.title,
                  amount: CurrencyFormatter.originalAmount(
                    minorUnits: item.amountMinorUnits,
                    currency: item.currency,
                  ),
                  type: item.type,
                  icon: Icons.star_rounded,
                  selected: selectedFavoriteId == item.id,
                  onTap: () => onFavoriteSelected(item),
                );
              }
              final recentIndex = index - favorites.length;
              if (recentIndex < recent.length) {
                final item = recent[recentIndex];
                final amount =
                    item.originalAmountMinorUnits != null &&
                        item.originalCurrency != null
                    ? CurrencyFormatter.originalAmount(
                        minorUnits: item.originalAmountMinorUnits!,
                        currency: item.originalCurrency!,
                      )
                    : CurrencyFormatter.usdFromCents(item.amountCents);
                return _PickCard(
                  key: ValueKey('quick-entry-${item.id}'),
                  title: item.title,
                  amount: amount,
                  type: item.type,
                  icon: p.isQuickEntryPinned(item.id)
                      ? Icons.push_pin_rounded
                      : null,
                  selected: selectedId == item.id,
                  onTap: () => onSelected(item),
                );
              }
              return Material(
                color: AppPalette.of(context).surfaceElevated,
                borderRadius: BorderRadius.circular(AppRadii.medium),
                child: InkWell(
                  onTap: onAddFavorite,
                  key: const ValueKey('add-favorite'),
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                  child: Container(
                    width: 148,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppPalette.of(context).border),
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add),
                        SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'New favorite',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

class _PickCard extends StatelessWidget {
  const _PickCard({
    super.key,
    required this.title,
    required this.amount,
    required this.type,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String title, amount, type;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${type == 'income' ? 'Received' : 'Spent'}, $title, $amount',
    child: Material(
      color: selected
          ? AppPalette.of(context).accentSoft
          : AppPalette.of(context).surfaceElevated,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: Container(
          width: 148,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? AppPalette.of(context).accent
                  : AppPalette.of(context).border,
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
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (icon != null)
                    Icon(icon, size: 15, color: AppPalette.of(context).accent),
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
}
