import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../providers/expense_provider.dart';
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
  String? _saveError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ExpenseProvider>();
    _rateController = TextEditingController(
      text: provider.exchangeRate.toStringAsFixed(
        provider.exchangeRate == provider.exchangeRate.roundToDouble() ? 0 : 2,
      ),
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

  Future<void> _copyBackup() async {
    final backup = context.read<ExpenseProvider>().exportState();
    await Clipboard.setData(ClipboardData(text: backup));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup copied to clipboard.')),
    );
  }

  Future<void> _restoreBackup() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Restore backup'),
          content: TextField(
            controller: controller,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Paste backup JSON here',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    final provider = context.read<ExpenseProvider>();
    final saved = await provider.importState(controller.text);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saveError = provider.errorMessage ?? 'Backup could not be restored.';
        _isSaving = false;
      });
    }
  }

  Future<void> _copyCsv() async {
    final csv = context.read<ExpenseProvider>().exportCsv();
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV copied to clipboard.')),
    );
  }

  Future<void> _importCsv() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Import CSV'),
          content: TextField(
            controller: controller,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(hintText: 'Paste CSV here'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Import'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    final provider = context.read<ExpenseProvider>();
    final saved = await provider.importCsv(controller.text);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saveError = provider.errorMessage ?? 'CSV could not be imported.';
        _isSaving = false;
      });
    }
  }

  Future<void> _resetAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset all data?'),
          content: const Text(
            'This removes all expenses and settings from this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    await context.read<ExpenseProvider>().resetStorage();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _saveBackupFile() async {
    final provider = context.read<ExpenseProvider>();
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${directory.path}/judgy-backup-$timestamp.json');
    await file.writeAsString(provider.exportState());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backup saved: ${file.path}')),
    );
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    final rate = CurrencyFormatter.parseAmount(_rateController.text);
    final budget = CurrencyFormatter.parseAmount(_budgetController.text);
    if (rate == null || budget == null) return;

    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    final provider = context.read<ExpenseProvider>();
    final saved = await provider.updateSettings(rate, budget);
    if (!mounted) return;

    if (saved) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saveError = provider.errorMessage ?? 'Settings could not be saved.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: 'Budget & currency',
      subtitle: 'Set the rate used for conversions and your monthly target.',
      closeLabel: 'Close settings',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _rateController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Exchange rate',
                helperText: 'How many YER equal 1 USD?',
                suffixText: 'YER / USD',
              ),
              validator: (value) {
                final rate = CurrencyFormatter.parseAmount(value ?? '');
                if (rate == null) return 'Enter a valid exchange rate.';
                if (rate <= 0) return 'Exchange rate must be above zero.';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _budgetController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Monthly budget',
                helperText: 'Stored in USD and converted for display.',
                suffixText: 'USD',
              ),
              validator: (value) {
                final budget = CurrencyFormatter.parseAmount(value ?? '');
                if (budget == null) return 'Enter a valid monthly budget.';
                if (budget < 0) return 'Budget cannot be negative.';
                return null;
              },
              onFieldSubmitted: (_) => _save(),
            ),
            if (_saveError != null) ...[
              const SizedBox(height: AppSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  _saveError!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_isSaving ? 'Saving…' : 'Save settings'),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Backup',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Copy your data to the clipboard or restore it from a backup.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _copyBackup,
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('Copy backup'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _restoreBackup,
                    icon: const Icon(Icons.restore_outlined),
                    label: const Text('Restore'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _copyCsv,
                    icon: const Icon(Icons.table_chart_outlined),
                    label: const Text('Copy CSV'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _importCsv,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Import CSV'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _resetAll,
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Reset all data'),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _saveBackupFile,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save backup file'),
            ),
          ],
        ),
      ),
    );
  }
}
