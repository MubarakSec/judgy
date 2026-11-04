import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../providers/expense_provider.dart';
import '../services/backup_files.dart';
import '../services/local_snapshots.dart';
import '../services/quick_add_notifications.dart';
import '../theme/app_theme.dart';
import 'category_manager_sheet.dart';
import '../utils/currency_formatter.dart';
import '../widgets/app_sheet.dart';
import 'category_budget_editor.dart';

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});
  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _rateController;
  final _files = const BackupFiles();
  final _snapshots = LocalSnapshots();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ExpenseProvider>();
    _rateController = TextEditingController(
      text: provider.exchangeRate.toString(),
    );
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message.toString()
              : 'The operation could not finish. Your data is still available; please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _requireSaved(bool saved, ExpenseProvider provider) {
    if (!saved) {
      throw FormatException(
        provider.errorMessage ?? 'Changes could not be saved.',
      );
    }
  }

  Future<void> _save() => _run(() async {
    if (!_formKey.currentState!.validate()) return;
    final p = context.read<ExpenseProvider>();
    _requireSaved(
      await p.setExchangeRate(
        CurrencyFormatter.parseAmount(_rateController.text)!,
      ),
      p,
    );
    if (mounted) Navigator.of(context).pop(true);
  });

  Future<void> _setQuickAddNotification(bool enabled) => _run(() async {
    final provider = context.read<ExpenseProvider>();
    _requireSaved(
      await provider.setShowQuickAddNotification(enabled),
      provider,
    );
    final applied = await QuickAddNotifications.syncQuickAdd(enabled);
    if (enabled && !applied) {
      _message(
        'Allow Judgy notifications in Android settings to use quick add.',
      );
    }
  });

  Future<void> _editCategoryBudget([String? existing]) async {
    final provider = context.read<ExpenseProvider>();
    final categories = <String>{
      ...provider.categoriesFor('expense').map((category) => category.label),
      ...provider.expenses.where((e) => !e.isIncome).map((e) => e.category),
      ...provider.categoryBudgetCents.keys,
    }.toList()..sort();
    final available = existing == null
        ? categories
              .where(
                (category) =>
                    !provider.categoryBudgetCents.containsKey(category),
              )
              .toList()
        : categories;
    if (available.isEmpty) return;
    final change = await showDialog<CategoryBudgetChange>(
      context: context,
      builder: (_) => CategoryBudgetEditor(
        categories: available,
        isUsd: provider.isUSD,
        exchangeRate: provider.exchangeRate,
        initialCategory: existing,
        initialCents: existing == null
            ? null
            : provider.categoryBudgetCents[existing],
      ),
    );
    if (change == null || !mounted) return;
    await _run(() async {
      _requireSaved(
        await provider.setCategoryBudget(change.category, change.cents),
        provider,
      );
    });
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _restore(
    String source, {
    bool csv = false,
    String name = 'Backup',
  }) async {
    final p = context.read<ExpenseProvider>();
    final count = csv
        ? p.previewCsv(source).length
        : p.previewBackup(source).expenses.length;
    if (!await _confirm(
          'Review restore',
          '$name contains $count transactions. This will replace your ${p.expenses.length} current transactions${csv ? '' : ' and budget settings'}. A recovery copy of the current data will be kept. Device lock settings stay unchanged.',
          'Replace data',
        ) ||
        !mounted) {
      return;
    }
    _requireSaved(await (csv ? p.importCsv(source) : p.importState(source)), p);
    if (!mounted) return;
    _rateController.text = p.exchangeRate.toString();
    _message('Restored $count transactions.');
  }

  Future<void> _restoreFile() => _run(() async {
    final file = await _files.pick();
    if (file != null && mounted) {
      await _restore(file.source, csv: file.csv, name: file.name);
    }
  });
  Future<void> _export({bool csv = false}) => _run(() async {
    final p = context.read<ExpenseProvider>();
    final shared = await _files.share(
      csv ? p.exportCsv() : p.exportState(),
      csv: csv,
    );
    if (shared) {
      _message(
        csv ? 'CSV shared.' : 'Backup shared. Keep a copy outside this app.',
      );
    }
  });
  Future<void> _clipboard(String operation) => _run(() async {
    final p = context.read<ExpenseProvider>();
    if (operation.startsWith('copy')) {
      await Clipboard.setData(
        ClipboardData(
          text: operation == 'copy-json' ? p.exportState() : p.exportCsv(),
        ),
      );
      _message('Copied to clipboard.');
      return;
    }
    final csv = operation == 'paste-csv';
    final source = await showDialog<String>(
      context: context,
      builder: (_) => _PasteBackupDialog(csv: csv),
    );
    if (source != null && mounted) await _restore(source, csv: csv);
  });
  Future<void> _recovery() => _run(() async {
    final source = await context.read<ExpenseProvider>().recoveryBackup();
    if (!mounted) return;
    if (source == null) {
      _message('A recovery copy is created before an import replaces data.');
      return;
    }
    await _restore(source, name: 'Previous data');
  });
  Future<void> _dailySnapshot() => _run(() async {
    final files = await _snapshots.files();
    if (!mounted) return;
    if (files.isEmpty) {
      _message(
        'A local snapshot is saved on the first transaction write each day.',
      );
      return;
    }
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Daily snapshots'),
        children: [
          for (var i = 0; i < files.length; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, i),
              child: Text(LocalSnapshots.dateLabel(files[i])),
            ),
        ],
      ),
    );
    if (selected != null && mounted) {
      await _restore(
        await files[selected].readAsString(),
        name: 'Snapshot ${LocalSnapshots.dateLabel(files[selected])}',
      );
    }
  });

  Future<void> _lock(bool enabled) => _run(() async {
    final p = context.read<ExpenseProvider>();
    if (enabled && !await LocalAuthentication().isDeviceSupported()) {
      throw const FormatException(
        'Set up a device screen lock or biometrics in Android Settings first.',
      );
    }
    if (!mounted) return;
    _requireSaved(await p.setRequireBiometric(enabled), p);
  });
  Future<void> _reset() => _run(() async {
    if (!await _confirm(
          'Reset all data?',
          'This removes all transactions, recurring templates, recovery copies, and settings from this device. Export a backup first if you want to keep them.',
          'Reset all data',
        ) ||
        !mounted) {
      return;
    }
    final p = context.read<ExpenseProvider>();
    _requireSaved(await p.resetStorage(), p);
    if (mounted) Navigator.pop(context, true);
  });

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ExpenseProvider>();
    final disabled = _busy || p.isSaving;
    return AppSheet(
      title: 'Settings',
      subtitle: 'Your budget, privacy, and data.',
      closeLabel: 'Close settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'system', label: Text('System')),
              ButtonSegment(value: 'light', label: Text('Light')),
              ButtonSegment(value: 'dark', label: Text('Dark')),
            ],
            selected: {p.themeMode},
            onSelectionChanged: disabled
                ? null
                : (selection) async {
                    final saved = await p.setThemeMode(selection.first);
                    if (!saved && context.mounted) {
                      _message(p.errorMessage ?? 'Theme could not be saved.');
                    }
                  },
          ),
          const SizedBox(height: AppSpacing.md),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.category_outlined),
            title: const Text('Categories'),
            subtitle: const Text('Edit names and symbols, or add your own'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: disabled
                ? null
                : () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const CategoryManagerSheet(),
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              children: [
                TextFormField(
                  controller: _rateController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Exchange rate',
                    helperText: 'Yemeni riyals per 1 USD',
                    suffixText: 'YER / USD',
                  ),
                  validator: (v) {
                    final n = CurrencyFormatter.parseAmount(v ?? '');
                    return n == null || n <= 0 || n > 1000000
                        ? 'Enter a rate above zero, up to 1,000,000.'
                        : null;
                  },
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: AppPalette.of(context).danger),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: disabled ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(_busy ? 'Working…' : 'Save settings'),
          ),
          const SizedBox(height: AppSpacing.lg),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            leading: const Icon(Icons.category_outlined),
            title: const Text('Category budgets'),
            subtitle: Text(
              p.categoryBudgetCents.isEmpty
                  ? 'Set monthly limits for your spending'
                  : '${p.categoryBudgetCents.length} monthly ${p.categoryBudgetCents.length == 1 ? 'limit' : 'limits'}',
            ),
            children: [
              for (final category
                  in p.categoryBudgetCents.keys.toList()..sort())
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(category),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${CurrencyFormatter.displayFromUsdCents(usdCents: p.categoryTotals[category] ?? 0, isUsd: p.isUSD, exchangeRate: p.exchangeRate)} of ${CurrencyFormatter.displayFromUsdCents(usdCents: p.categoryBudgetCents[category]!, isUsd: p.isUSD, exchangeRate: p.exchangeRate)} this month',
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      LinearProgressIndicator(
                        value:
                            ((p.categoryTotals[category] ?? 0) /
                                    p.categoryBudgetCents[category]!)
                                .clamp(0.0, 1.0),
                        color:
                            (p.categoryTotals[category] ?? 0) >
                                p.categoryBudgetCents[category]!
                            ? AppPalette.of(context).danger
                            : AppPalette.of(context).accent,
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: disabled ? null : () => _editCategoryBudget(category),
                ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: disabled ? null : () => _editCategoryBudget(),
                icon: const Icon(Icons.add),
                label: const Text('Add category budget'),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Quick add'),
            subtitle: const Text('Access the entry sheet from notifications'),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Keep quick add in notifications'),
                subtitle: const Text(
                  'Tap it to add over your current app. Turn it off to clear the notification.',
                ),
                value: p.showQuickAddNotification,
                onChanged: disabled ? null : _setQuickAddNotification,
              ),
            ],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            leading: const Icon(Icons.shield_outlined),
            title: const Text('Privacy'),
            subtitle: const Text('Device unlock and local storage'),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Require device unlock'),
                subtitle: const Text(
                  'Use your fingerprint, face, or device PIN. Locks when you leave the app.',
                ),
                value: p.requireBiometric,
                onChanged: disabled ? null : _lock,
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  'Transaction records stay on this device. Android cloud backup is disabled.',
                ),
              ),
            ],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup & restore'),
            subtitle: const Text(
              'Export a portable copy or restore your history',
            ),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.ios_share_rounded),
                title: const Text('Export backup'),
                subtitle: const Text(
                  'JSON · transactions, templates, and settings',
                ),
                onTap: disabled ? null : () => _export(),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('Restore from file'),
                subtitle: const Text(
                  'Review JSON or CSV before replacing data',
                ),
                onTap: disabled ? null : _restoreFile,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.table_chart_outlined),
                title: const Text('Export spreadsheet'),
                subtitle: const Text(
                  'CSV · includes notes and original currency',
                ),
                onTap: disabled ? null : () => _export(csv: true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history_rounded),
                title: const Text('Recover previous data'),
                subtitle: const Text('The copy kept before the last import'),
                onTap: disabled ? null : _recovery,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restore_page_outlined),
                title: const Text('Daily snapshots'),
                subtitle: const Text(
                  'Seven local copies · export for protection from device loss',
                ),
                onTap: disabled ? null : _dailySnapshot,
              ),
              PopupMenuButton<String>(
                enabled: !disabled,
                tooltip: 'Clipboard backup options',
                onSelected: _clipboard,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'copy-json',
                    child: Text('Copy backup JSON'),
                  ),
                  PopupMenuItem(value: 'copy-csv', child: Text('Copy CSV')),
                  PopupMenuItem(
                    value: 'paste-json',
                    child: Text('Paste backup JSON'),
                  ),
                  PopupMenuItem(value: 'paste-csv', child: Text('Paste CSV')),
                ],
                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.content_paste_outlined),
                  title: Text('Clipboard options'),
                  trailing: Icon(Icons.more_horiz),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton.icon(
            onPressed: disabled ? null : _reset,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Reset all data'),
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.of(context).danger,
            ),
          ),
        ],
      ),
    );
  }
}

class _PasteBackupDialog extends StatefulWidget {
  const _PasteBackupDialog({required this.csv});
  final bool csv;
  @override
  State<_PasteBackupDialog> createState() => _PasteBackupDialogState();
}

class _PasteBackupDialogState extends State<_PasteBackupDialog> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.csv ? 'Paste CSV' : 'Paste backup'),
    content: TextField(
      controller: _controller,
      minLines: 4,
      maxLines: 8,
      decoration: InputDecoration(
        hintText: widget.csv ? 'CSV with a header row' : 'Judgy backup JSON',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('Review'),
      ),
    ],
  );
}
