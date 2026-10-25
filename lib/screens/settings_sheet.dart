import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          ],
        ),
      ),
    );
  }
}
