import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../utils/voice_expense_parser.dart';
import '../utils/expense_categories.dart';
import '../utils/judgy_quotes.dart';
import '../widgets/app_sheet.dart';

class AddExpenseSheet extends StatefulWidget {
  const AddExpenseSheet({super.key});

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedCategory = ExpenseCategory.labels.first;
  String? _submitError;
  bool _isSubmitting = false;
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;

  @override
  void dispose() {
    _speech.stop();
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    final available = await _speech.initialize();
    if (!available) {
      if (mounted) {
        setState(() => _submitError = 'Speech recognition is unavailable.');
      }
      return;
    }
    if (mounted) setState(() => _isListening = true);
    await _speech.listen(
      listenOptions: SpeechListenOptions(localeId: 'ar_SA'),
      onResult: (result) {
        final parsed = VoiceExpenseParser.parse(result.recognizedWords);
        _titleController.text = parsed.title;
        if (parsed.amount != null) {
          _amountController.text = parsed.amount!.toString();
        }
        if (result.finalResult && mounted) {
          setState(() => _isListening = false);
        }
      },
    );
  }

  Future<void> _submitData() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

    final provider = context.read<ExpenseProvider>();
    final enteredAmount = CurrencyFormatter.parseAmount(_amountController.text);
    if (enteredAmount == null) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final expense = Expense.fromEnteredAmount(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        enteredAmount: enteredAmount,
        currency: provider.isUSD ? 'USD' : 'YER',
        exchangeRate: provider.exchangeRate,
        date: provider.now,
        category: _selectedCategory,
      );
      final saved = await provider.addExpense(expense);
      if (!mounted) return;

      if (saved) {
        final quote = JudgyQuotes.getQuote(_selectedCategory, expense.amount);
        Navigator.of(context).pop(quote);
      } else {
        setState(() {
          _submitError = provider.errorMessage ?? 'Expense could not be saved.';
          _isSubmitting = false;
        });
      }
    } on ArgumentError catch (_) {
      if (!mounted) return;
      setState(() {
        _submitError =
            'That amount cannot be stored. Check the value and try again.';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final currencyCode = provider.isUSD ? 'USD' : 'YER';

    return AppSheet(
      title: 'Add an expense',
      subtitle: 'A quick entry keeps the picture honest.',
      closeLabel: 'Close add expense',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              inputFormatters: [LengthLimitingTextInputFormatter(80)],
              decoration: InputDecoration(
                labelText: 'Expense name',
                hintText: 'Coffee, groceries, taxi…',
                suffixIcon: IconButton(
                  tooltip: _isListening ? 'Stop listening' : 'Add by voice',
                  onPressed: _isSubmitting ? null : _toggleListening,
                  icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter what you spent money on.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Amount',
                hintText: provider.isUSD ? '0.00' : '0',
                suffixText: currencyCode,
              ),
              validator: (value) {
                final amount = CurrencyFormatter.parseAmount(value ?? '');
                if (amount == null) return 'Enter a valid amount.';
                if (amount <= 0) return 'Amount must be greater than zero.';
                if (provider.isUSD && amount < 0.01) {
                  return 'The minimum USD amount is 0.01.';
                }
                return null;
              },
              onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              isExpanded: true,
              dropdownColor: AppColors.surfaceElevated,
              decoration: const InputDecoration(labelText: 'Category'),
              items: ExpenseCategory.labels
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: _isSubmitting
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _selectedCategory = value);
                      }
                    },
            ),
            if (_submitError != null) ...[
              const SizedBox(height: AppSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  _submitError!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submitData,
              icon: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_isSubmitting ? 'Saving…' : 'Save expense'),
            ),
          ],
        ),
      ),
    );
  }
}
