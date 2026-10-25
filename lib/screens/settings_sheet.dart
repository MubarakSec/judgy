import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../providers/expense_provider.dart';
import '../services/backup_files.dart';
import '../services/local_snapshots.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../widgets/app_sheet.dart';

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});
  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _rateController;
  late final TextEditingController _budgetController;
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
    _budgetController = TextEditingController(
      text: provider.monthlyBudget.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _rateController.dispose();
    _budgetController.dispose();
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
      await p.updateSettings(
        CurrencyFormatter.parseAmount(_rateController.text)!,
        CurrencyFormatter.parseAmount(_budgetController.text)!,
      ),
      p,
    );
    if (mounted) Navigator.of(context).pop(true);
  });

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
          '$name contains $count expenses. This will replace your ${p.expenses.length} current expenses${csv ? '' : ' and budget settings'}. A recovery copy of the current data will be kept. Device lock settings stay unchanged.',
          'Replace data',
        ) ||
        !mounted) {
      return;
    }
    _requireSaved(await (csv ? p.importCsv(source) : p.importState(source)), p);
    if (!mounted) return;
    _rateController.text = p.exchangeRate.toString();
    _budgetController.text = p.monthlyBudget.toStringAsFixed(2);
    _message('Restored $count expenses.');
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
        'A local snapshot is saved on the first expense write each day.',
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
          'This removes all expenses, recurring templates, recovery copies, and settings from this device. Export a backup first if you want to keep them.',
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
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _budgetController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Monthly budget',
                    helperText: 'Use zero to turn off the budget.',
                    suffixText: 'USD',
                  ),
                  validator: (v) {
                    final n = CurrencyFormatter.parseAmount(v ?? '');
                    return n == null || n < 0 || n > 9007199254740991 / 100
                        ? 'Enter a valid budget of zero or more.'
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
                  style: const TextStyle(color: AppColors.danger),
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
                  'Expense records stay on this device. Voice uses on-device recognition by default; online processing is optional in voice settings.',
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
                  'JSON · expenses, templates, and settings',
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
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
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
