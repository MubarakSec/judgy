import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../utils/expense_categories.dart';
import '../utils/judgy_quotes.dart';
import '../widgets/app_sheet.dart';
import '../widgets/voice_entry_panel.dart';
import '../services/voice_input_controller.dart';

class AddExpenseSheet extends StatefulWidget {
  const AddExpenseSheet({
    super.key,
    this.expense,
    this.duplicate = false,
    this.voiceController,
  });

  final Expense? expense;
  final bool duplicate;
  final VoiceInputController? voiceController;

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
  bool _showVoice = false;
  late String _entryCurrency;
  String? _initialAmountText;
  String? _initialCurrency;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    final provider = context.read<ExpenseProvider>();
    _selectedDate = widget.duplicate
        ? provider.now
        : expense?.date ?? provider.now;
    _entryCurrency = provider.isUSD ? 'USD' : 'YER';
    if (expense != null) {
      _titleController.text = expense.title;
      _noteController.text = expense.note ?? '';
      _selectedCategory = expense.category;
      final original = expense.originalCurrency;
      if ((original == 'USD' || original == 'YER') &&
          expense.originalAmount != null) {
        _entryCurrency = original!;
        _amountController.text = expense.originalAmount!.toStringAsFixed(2);
      } else {
        final amount = _entryCurrency == 'USD'
            ? expense.amount
            : expense.amount * provider.exchangeRate;
        _amountController.text = amount.toStringAsFixed(2);
      }
      _initialAmountText = _amountController.text;
      _initialCurrency = _entryCurrency;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitData() async {
    if (_isSubmitting || _showVoice || !_formKey.currentState!.validate()) {
      return;
    }

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
      final original = widget.expense;
      final preserveAmount =
          original != null &&
          _amountController.text == _initialAmountText &&
          _entryCurrency == _initialCurrency;
      final expense = preserveAmount
          ? Expense(
              id: expenseId,
              title: _titleController.text.trim(),
              amountCents: original.amountCents,
              date: _selectedDate,
              category: _selectedCategory,
              note: _noteController.text,
              originalAmountMinorUnits: original.originalAmountMinorUnits,
              originalCurrency: original.originalCurrency,
              exchangeRateAtEntry: original.exchangeRateAtEntry,
            )
          : Expense.fromEnteredAmount(
              id: expenseId,
              title: _titleController.text.trim(),
              enteredAmount: enteredAmount,
              currency: _entryCurrency,
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
    } catch (_) {
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
    final currencyCode = _entryCurrency;

    return AppSheet(
      title: widget.expense == null
          ? 'Add an expense'
          : widget.duplicate
          ? 'Duplicate expense'
          : 'Edit expense',
      subtitle: 'A quick entry keeps the picture honest.',
      closeLabel: 'Close add expense',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_showVoice)
              VoiceEntryPanel(
                controller: widget.voiceController,
                onClose: () => setState(() => _showVoice = false),
                onApply: (draft, currency) => setState(() {
                  _titleController.text = draft.title;
                  _amountController.text = draft.amount!.toString();
                  _entryCurrency = currency;
                  _selectedDate = draft.date;
                  _selectedCategory = draft.category;
                  _submitError = null;
                  _showVoice = false;
                }),
              ),
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              inputFormatters: [LengthLimitingTextInputFormatter(80)],
              decoration: InputDecoration(
                labelText: 'Expense name',
                hintText: 'Coffee, groceries, taxi…',
                suffixIcon: IconButton(
                  tooltip: 'Add by voice',
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() => _showVoice = !_showVoice),
                  icon: Icon(_showVoice ? Icons.mic : Icons.mic_none),
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
                hintText: currencyCode == 'USD' ? '0.00' : '0',
                suffixIcon: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: currencyCode,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'USD', child: Text('USD')),
                      DropdownMenuItem(value: 'YER', child: Text('YER')),
                    ],
                    onChanged: _isSubmitting
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _entryCurrency = value);
                            }
                          },
                  ),
                ),
              ),
              validator: (value) {
                final amount = CurrencyFormatter.parseAmount(value ?? '');
                if (amount == null) return 'Enter a valid amount.';
                if (amount <= 0) return 'Amount must be greater than zero.';
                if (currencyCode == 'USD' && amount < 0.01) {
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
                        initialDate: _selectedDate.isAfter(provider.now)
                            ? provider.now
                            : _selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: provider.now,
                      );
                      if (picked != null && mounted) {
                        setState(() => _selectedDate = picked);
                      }
                    },
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                MaterialLocalizations.of(
                  context,
                ).formatMediumDate(_selectedDate),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              key: ValueKey(_selectedCategory),
              initialValue: _selectedCategory,
              isExpanded: true,
              dropdownColor: AppColors.surfaceElevated,
              decoration: const InputDecoration(labelText: 'Category'),
              items: {...ExpenseCategory.labels, _selectedCategory}
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
              onPressed: _isSubmitting || _showVoice ? null : _submitData,
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
