import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
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
  const AddExpenseSheet({super.key, this.expense, this.duplicate = false});

  final Expense? expense;
  final bool duplicate;

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _selectedCategory = ExpenseCategory.labels.first;
  late DateTime _selectedDate;
  String? _submitError;
  bool _isSubmitting = false;
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    final provider = context.read<ExpenseProvider>();
    _selectedDate = expense?.date ?? provider.now;
    if (expense != null) {
      _titleController.text = expense.title;
      _noteController.text = expense.note ?? '';
      _selectedCategory = expense.category;
      final currentIsUsd = provider.isUSD;
      final amount = currentIsUsd
          ? expense.amount
          : expense.amount * provider.exchangeRate;
      _amountController.text = amount.toStringAsFixed(currentIsUsd ? 2 : 0);
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
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
      final isEditing = widget.expense != null && !widget.duplicate;
    final expenseId = isEditing ? widget.expense!.id : const Uuid().v4();
    final expense = Expense.fromEnteredAmount(
        id: expenseId,
        title: _titleController.text.trim(),
        enteredAmount: enteredAmount,
        currency: provider.isUSD ? 'USD' : 'YER',
        exchangeRate: provider.exchangeRate,
        date: _selectedDate,
        category: _selectedCategory,
        note: _noteController.text,
      );
      final saved = isEditing
          ? await provider.updateExpense(expense)
          : await provider.addExpense(expense);
      if (!mounted) return;

      if (saved) {
        HapticFeedback.lightImpact();
        if (isEditing) {
          Navigator.of(context).pop(true);
        } else {
          final quote = JudgyQuotes.getQuote(_selectedCategory, expense.amount);
          Navigator.of(context).pop(quote);
        }
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
            OutlinedButton.icon(
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null && mounted) {
                        setState(() => _selectedDate = picked);
                      }
                    },
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                MaterialLocalizations.of(context).formatMediumDate(_selectedDate),
              ),
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
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Anything to remember',
              ),
              maxLines: 2,
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
