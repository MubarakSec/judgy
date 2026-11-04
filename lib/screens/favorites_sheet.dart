import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/favorite_template.dart';
import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../widgets/app_sheet.dart';

class FavoriteChange {
  const FavoriteChange.save(this.favorite) : remove = false;
  const FavoriteChange.remove() : favorite = null, remove = true;
  final FavoriteTemplate? favorite;
  final bool remove;
}

class FavoriteEditorDialog extends StatefulWidget {
  const FavoriteEditorDialog({
    super.key,
    this.initial,
    this.draftTitle,
    this.draftAmount,
    this.draftCurrency,
    this.draftCategory,
    this.draftType = 'expense',
  });

  final FavoriteTemplate? initial;
  final String? draftTitle;
  final double? draftAmount;
  final String? draftCurrency;
  final String? draftCategory;
  final String draftType;

  @override
  State<FavoriteEditorDialog> createState() => _FavoriteEditorDialogState();
}

class _FavoriteEditorDialogState extends State<FavoriteEditorDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  late String _type;
  late String _currency;
  late String _category;

  String _defaultCategory(ExpenseProvider p, String type) {
    final names = p.categoriesFor(type).map((item) => item.label).toList();
    final preferred = type == 'income' ? 'Income' : 'Other';
    return names.contains(preferred) ? preferred : names.first;
  }

  @override
  void initState() {
    super.initState();
    final p = context.read<ExpenseProvider>();
    final item = widget.initial;
    _type = item?.type ?? widget.draftType;
    _currency =
        item?.currency ?? widget.draftCurrency ?? (p.isUSD ? 'USD' : 'YER');
    _category =
        item?.category ?? widget.draftCategory ?? _defaultCategory(p, _type);
    _title.text = item?.title ?? widget.draftTitle ?? '';
    final amount = item?.amount ?? widget.draftAmount;
    if (item != null) {
      _amount.text = CurrencyFormatter.amountInputFromMinorUnits(
        item.amountMinorUnits,
      );
    } else if (amount != null && amount > 0) {
      _amount.text = amount.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final amount = CurrencyFormatter.parseAmount(_amount.text)!;
    final favorite = FavoriteTemplate(
      id: widget.initial?.id ?? const Uuid().v4(),
      title: _title.text.trim(),
      amountMinorUnits: (amount * 100).round(),
      currency: _currency,
      category: _category,
      type: _type,
    );
    favorite.validate();
    Navigator.pop(context, FavoriteChange.save(favorite));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ExpenseProvider>();
    final names = p.categoriesFor(_type).map((e) => e.label).toSet();
    names.add(_category);
    return AlertDialog(
      title: Text(widget.initial == null ? 'New favorite' : 'Edit favorite'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'expense', label: Text('Spent')),
                  ButtonSegment(value: 'income', label: Text('Received')),
                ],
                selected: {_type},
                onSelectionChanged: (selection) => setState(() {
                  _type = selection.first;
                  _category = _defaultCategory(p, _type);
                }),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _title,
                inputFormatters: [LengthLimitingTextInputFormatter(80)],
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a name.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  suffixText: _currency,
                ),
                validator: (value) {
                  final amount = CurrencyFormatter.parseAmount(value ?? '');
                  if (amount == null ||
                      amount <= 0 ||
                      amount > 9007199254740991 / 100) {
                    return 'Enter a valid amount above zero.';
                  }
                  try {
                    // The shortcut must be usable as a transaction at the current rate.
                    final cents = _currency == 'USD'
                        ? amount
                        : amount / p.exchangeRate;
                    if (cents < 0.01 || cents > 9007199254740991 / 100) {
                      return 'Amount cannot be saved at this exchange rate.';
                    }
                  } catch (_) {
                    return 'Enter a valid amount.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                key: ValueKey('favorite-currency-$_currency'),
                initialValue: _currency,
                decoration: const InputDecoration(labelText: 'Currency'),
                items: const [
                  DropdownMenuItem(value: 'USD', child: Text('USD')),
                  DropdownMenuItem(value: 'YER', child: Text('YER')),
                ],
                onChanged: (value) =>
                    setState(() => _currency = value ?? _currency),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                key: ValueKey('favorite-category-$_type'),
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final name in names)
                    DropdownMenuItem(
                      value: name,
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _category = value ?? _category),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.initial != null)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, const FavoriteChange.remove()),
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class FavoritesSheet extends StatelessWidget {
  const FavoritesSheet({super.key});

  Future<void> _edit(BuildContext context, [FavoriteTemplate? initial]) async {
    final provider = context.read<ExpenseProvider>();
    final change = await showDialog<FavoriteChange>(
      context: context,
      builder: (_) => FavoriteEditorDialog(initial: initial),
    );
    if (change == null || !context.mounted) return;
    final saved = change.remove
        ? await provider.removeFavorite(initial!.id)
        : initial == null
        ? await provider.addFavorite(change.favorite!)
        : await provider.updateFavorite(change.favorite!);
    if (!saved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ?? 'Favorite could not be saved.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ExpenseProvider>();
    return AppSheet(
      title: 'Favorites',
      closeLabel: 'Close favorites',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final favorite in p.favorites)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                favorite.type == 'income'
                    ? Icons.south_west_rounded
                    : Icons.north_east_rounded,
                color: favorite.type == 'income'
                    ? AppPalette.of(context).success
                    : AppPalette.of(context).accent,
              ),
              title: Text(favorite.title),
              subtitle: Text(
                '${CurrencyFormatter.originalAmount(minorUnits: favorite.amountMinorUnits, currency: favorite.currency)} · ${favorite.category}',
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _edit(context, favorite),
            ),
          if (p.favorites.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                'Save a frequent entry here for one-tap reuse.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: p.favorites.length >= 12 ? null : () => _edit(context),
            icon: const Icon(Icons.add),
            label: const Text('Add favorite'),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
