import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../utils/expense_categories.dart';
import '../widgets/app_sheet.dart';

class AddExpenseSheet extends StatefulWidget {
  const AddExpenseSheet({
    super.key,
    this.expense,
    this.duplicate = false,
    this.suggestion,
  });

  final Expense? expense;
  final bool duplicate;
  final Expense? suggestion;

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _selectedCategory = 'Other';
  late DateTime _selectedDate;
  String? _submitError;
  bool _isSubmitting = false;
  bool _showDetails = false;
  String _type = 'expense';
  late String _entryCurrency;
  String? _initialAmountText;
  String? _initialCurrency;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense ?? widget.suggestion;
    _showDetails = widget.expense != null;
    final provider = context.read<ExpenseProvider>();
    _selectedDate = widget.duplicate || widget.suggestion != null
        ? provider.now
        : expense?.date ?? provider.now;
    _entryCurrency = provider.isUSD ? 'USD' : 'YER';
    if (expense != null) {
      _type = expense.type;
      _titleController.text = expense.title;
      _noteController.text = widget.suggestion == null
          ? expense.note ?? ''
          : '';
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
    if (_isSubmitting || !_formKey.currentState!.validate()) {
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
              type: _type,
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
              type: _type,
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
          Navigator.of(
            context,
          ).pop(_type == 'income' ? 'Income saved.' : 'Expense saved.');
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
          ? widget.suggestion == null
                ? 'Add a transaction'
                : 'Add again'
          : widget.duplicate
          ? 'Duplicate transaction'
          : 'Edit transaction',
      closeLabel: 'Close transaction form',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'expense',
                  label: Text('Spent'),
                  icon: Icon(Icons.arrow_upward),
                ),
                ButtonSegment(
                  value: 'income',
                  label: Text('Received'),
                  icon: Icon(Icons.arrow_downward),
                ),
              ],
              selected: {_type},
              onSelectionChanged: _isSubmitting
                  ? null
                  : (selection) => setState(() {
                      _type = selection.first;
                      _selectedCategory = _type == 'income'
                          ? 'Income'
                          : 'Other';
                    }),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              inputFormatters: [LengthLimitingTextInputFormatter(80)],
              decoration: InputDecoration(
                labelText: _type == 'income'
                    ? 'Where it came from'
                    : 'What you bought',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a name for this transaction.';
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
              onFieldSubmitted: (_) => _submitData(),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              key: ValueKey(_selectedCategory),
              initialValue: _selectedCategory,
              isExpanded: true,
              dropdownColor: AppColors.surfaceElevated,
              decoration: const InputDecoration(labelText: 'Category'),
              items:
                  {
                        ...(_type == 'income'
                            ? ['Income', 'Salary', 'Gift', 'Refund', 'Other']
                            : ExpenseCategory.labels),
                        _selectedCategory,
                      }
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
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () => setState(() => _showDetails = !_showDetails),
                icon: Icon(
                  _showDetails ? Icons.expand_less : Icons.expand_more,
                ),
                label: Text(_showDetails ? 'Fewer details' : 'Date and note'),
              ),
            ),
            if (_showDetails) ...[
              const SizedBox(height: AppSpacing.xs),
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
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
                maxLines: 2,
              ),
            ],
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
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submitData,
              icon: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(
                _isSubmitting
                    ? 'Saving…'
                    : _type == 'income'
                    ? 'Save income'
                    : 'Save expense',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
