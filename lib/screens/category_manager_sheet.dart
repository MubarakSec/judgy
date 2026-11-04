import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/ledger_category.dart';
import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';
import '../utils/expense_categories.dart';
import '../widgets/app_sheet.dart';

class CategoryManagerSheet extends StatefulWidget {
  const CategoryManagerSheet({super.key});

  @override
  State<CategoryManagerSheet> createState() => _CategoryManagerSheetState();
}

class _CategoryManagerSheetState extends State<CategoryManagerSheet> {
  String _type = 'expense';
  bool _busy = false;

  Future<void> _edit([LedgerCategory? existing]) async {
    if (_busy) return;
    final provider = context.read<ExpenseProvider>();
    final result = await showDialog<_CategoryEdit>(
      context: context,
      builder: (_) => _CategoryEditor(
        type: _type,
        initial: existing,
        existingNames: provider
            .categoriesFor(_type)
            .map((e) => e.label)
            .toList(),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    final saved = result.remove
        ? await provider.removeCategory(existing!.label, existing.type)
        : existing == null
        ? await provider.addCategory(result.category!)
        : await provider.updateCategory(
            oldLabel: existing.label,
            replacement: result.category!,
          );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ?? 'Category could not be saved.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final categories = provider.categoriesFor(_type);
    return AppSheet(
      title: 'Categories',
      subtitle: 'Names and symbols used when adding transactions.',
      closeLabel: 'Close categories',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'expense', label: Text('Spent')),
              ButtonSegment(value: 'income', label: Text('Received')),
            ],
            selected: {_type},
            onSelectionChanged: (selection) =>
                setState(() => _type = selection.first),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final category in categories)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                ExpenseCategory.iconForKey(category.iconKey),
                color: AppPalette.of(context).accent,
              ),
              title: Text(category.label),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _busy ? null : () => _edit(category),
            ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _edit(),
            icon: const Icon(Icons.add),
            label: Text(
              _type == 'income'
                  ? 'Add income category'
                  : 'Add spending category',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _CategoryEdit {
  const _CategoryEdit.save(this.category) : remove = false;
  const _CategoryEdit.remove() : category = null, remove = true;
  final LedgerCategory? category;
  final bool remove;
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({
    required this.type,
    required this.initial,
    required this.existingNames,
  });

  final String type;
  final LedgerCategory? initial;
  final List<String> existingNames;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  late String _iconKey;

  @override
  void initState() {
    super.initState();
    _name.text = widget.initial?.label ?? '';
    _iconKey =
        widget.initial?.iconKey ??
        (widget.type == 'income' ? 'income' : 'other');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      _CategoryEdit.save(
        LedgerCategory(
          label: _name.text.trim(),
          type: widget.type,
          iconKey: _iconKey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'Add category' : 'Edit category'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [LengthLimitingTextInputFormatter(40)],
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) {
                final name = value?.trim() ?? '';
                if (name.isEmpty) return 'Enter a category name.';
                if (widget.existingNames.any(
                  (existing) =>
                      existing.toLowerCase() == name.toLowerCase() &&
                      existing != widget.initial?.label,
                )) {
                  return 'A category with this name already exists.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Symbol', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final key in LedgerCategory.iconKeys)
                  Tooltip(
                    message: key,
                    child: ChoiceChip(
                      key: ValueKey('category-icon-$key'),
                      label: Icon(ExpenseCategory.iconForKey(key), size: 20),
                      selected: _iconKey == key,
                      onSelected: (_) => setState(() => _iconKey = key),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
    actions: [
      if (widget.initial != null)
        TextButton(
          onPressed: () => Navigator.pop(context, const _CategoryEdit.remove()),
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
