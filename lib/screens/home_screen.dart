import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/expense_tile.dart';
import '../widgets/time_filter_tabs.dart';
import '../widgets/total_spent_card.dart';
import '../models/expense.dart';
import '../utils/currency_formatter.dart';
import '../services/quick_add_notifications.dart';
import '../widgets/app_lock_gate.dart';
import 'add_expense_sheet.dart';
import 'settings_sheet.dart';
import 'insights_sheet.dart';
import 'recurring_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.openAddOnStart = false});

  final bool openAddOnStart;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  bool _ready = false;
  bool _pendingAdd = false;
  bool _addSheetOpen = false;
  late final ExpenseProvider _provider;
  String _searchQuery = '';
  String _sortMode = 'Date';

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppLockGate.sessionUnlocked.removeListener(_sessionChanged);
    QuickAddNotifications.addRequests.removeListener(_notificationAdd);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _provider = context.read<ExpenseProvider>();
    AppLockGate.sessionUnlocked.addListener(_sessionChanged);
    WidgetsBinding.instance.addObserver(this);
    QuickAddNotifications.addRequests.addListener(_notificationAdd);
    _pendingAdd = widget.openAddOnStart;
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await _provider.initialized;
    if (!mounted) return;
    setState(() => _ready = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openPendingAdd();
    });
  }

  void _sessionChanged() {
    if (AppLockGate.sessionUnlocked.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openPendingAdd();
          unawaited(_provider.reconcileRecurring());
        }
      });
    }
  }

  void _notificationAdd() {
    _pendingAdd = true;
    _openPendingAdd();
  }

  void _openPendingAdd() {
    if (!_pendingAdd ||
        !mounted ||
        !_ready ||
        _addSheetOpen ||
        !AppLockGate.sessionUnlocked.value) {
      return;
    }
    _pendingAdd = false;
    unawaited(_openAddExpense(context));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _ready &&
        AppLockGate.sessionUnlocked.value) {
      unawaited(_provider.reconcileRecurring());
    }
  }

  Future<void> _openAddExpense(BuildContext context) async {
    if (_addSheetOpen || !_ready || !AppLockGate.sessionUnlocked.value) return;
    _addSheetOpen = true;
    final quote = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierLabel: 'Close add expense',
      builder: (_) => const AddExpenseSheet(),
    );
    _addSheetOpen = false;
    if (quote == null || !context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Saved. $quote')));
  }

  Future<void> _openSettings(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierLabel: 'Close settings',
      builder: (_) => const SettingsSheet(),
    );
    if (saved != true || !context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Settings saved.')));
  }

  Future<void> _openInsights(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierLabel: 'Close insights',
      builder: (_) => const InsightsSheet(),
    );
  }

  Future<void> _openRecurring(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierLabel: 'Close recurring expenses',
      builder: (_) => const RecurringSheet(),
    );
  }

  Future<void> _toggleCurrency(
    BuildContext context,
    ExpenseProvider provider,
  ) async {
    final saved = await provider.toggleCurrency();
    if (saved || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          provider.errorMessage ?? 'Currency preference could not be saved.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final filtered = provider.filteredExpenses;
    final query = _searchQuery.trim().toLowerCase();
    final visibleExpenses = query.isEmpty
        ? filtered
        : filtered
              .where(
                (expense) =>
                    expense.title.toLowerCase().contains(query) ||
                    expense.category.toLowerCase().contains(query) ||
                    (expense.note?.toLowerCase().contains(query) ?? false) ||
                    CurrencyFormatter.displayFromUsdCents(
                      usdCents: expense.amountCents,
                      isUsd: provider.isUSD,
                      exchangeRate: provider.exchangeRate,
                    ).toLowerCase().contains(query),
              )
              .toList(growable: false);
    final sortedExpenses = List<Expense>.from(visibleExpenses);
    switch (_sortMode) {
      case 'Amount':
        sortedExpenses.sort((a, b) => b.amountCents.compareTo(a.amountCents));
        break;
      case 'Title':
        sortedExpenses.sort((a, b) => a.title.compareTo(b.title));
        break;
      default:
        sortedExpenses.sort((a, b) => b.date.compareTo(a.date));
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.lg,
        title: Text('Judgy', style: Theme.of(context).textTheme.headlineLarge),
        actions: [
          Tooltip(
            message: provider.isUSD
                ? 'Switch display to YER'
                : 'Switch display to USD',
            child: ActionChip(
              avatar: const Icon(Icons.currency_exchange, size: 18),
              label: Text(provider.isUSD ? 'USD' : 'YER'),
              onPressed: provider.isSaving
                  ? null
                  : () => _toggleCurrency(context, provider),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'More options',
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (value) => value == 'insights'
                ? _openInsights(context)
                : _openRecurring(context),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'insights',
                child: ListTile(
                  leading: Icon(Icons.insights_outlined),
                  title: Text('Spending insights'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'recurring',
                child: ListTile(
                  leading: Icon(Icons.repeat_outlined),
                  title: Text('Recurring expenses'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Budget and currency settings',
            onPressed: provider.isLoading || provider.isSaving
                ? null
                : () => _openSettings(context),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: provider.isLoading
          ? const _LoadingHome()
          : CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.xs),
                        const TimeFilterTabs(),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Search expenses',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_searchQuery.isNotEmpty)
                                  IconButton(
                                    tooltip: 'Clear search',
                                    icon: const Icon(Icons.close, size: 20),
                                    onPressed: () => setState(() {
                                      _searchQuery = '';
                                      _searchController.clear();
                                    }),
                                  ),
                                PopupMenuButton<String>(
                                  tooltip: 'Sort expenses',
                                  initialValue: _sortMode,
                                  icon: Icon(
                                    Icons.sort_rounded,
                                    color: _sortMode == 'Date'
                                        ? AppColors.textSecondary
                                        : AppColors.accent,
                                  ),
                                  onSelected: (value) =>
                                      setState(() => _sortMode = value),
                                  itemBuilder: (_) => [
                                    for (final entry in const {
                                      'Date': 'Newest first',
                                      'Amount': 'Highest amount',
                                      'Title': 'Name A–Z',
                                    }.entries)
                                      CheckedPopupMenuItem(
                                        value: entry.key,
                                        checked: _sortMode == entry.key,
                                        child: Text(entry.value),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          onChanged: (value) =>
                              setState(() => _searchQuery = value),
                        ),
                        if (provider.errorMessage != null ||
                            provider.warningMessage != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          _StatusNotice(
                            message:
                                provider.errorMessage ??
                                provider.warningMessage!,
                            isError: provider.errorMessage != null,
                            onDismiss: provider.errorMessage != null
                                ? provider.clearError
                                : provider.clearWarning,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        const TotalSpentCard(),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Recent expenses',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  sliver: sortedExpenses.isEmpty
                      ? SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyState(
                            hasAnyExpenses: provider.expenses.isNotEmpty,
                            period: query.isEmpty
                                ? provider.timeFilter.toLowerCase()
                                : 'matching "$_searchQuery"',
                            onAdd: () => _openAddExpense(context),
                          ),
                        )
                      : SliverList.builder(
                          itemCount: sortedExpenses.length,
                          itemBuilder: (_, index) =>
                              ExpenseTile(expense: sortedExpenses[index]),
                        ),
                ),
                if (sortedExpenses.isNotEmpty)
                  const SliverToBoxAdapter(child: SizedBox(height: 104)),
              ],
            ),
      floatingActionButton: !provider.isLoading && filtered.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _openAddExpense(context),
              icon: const Icon(Icons.add),
              label: const Text('Add expense'),
            )
          : null,
    );
  }
}

class _LoadingHome extends StatelessWidget {
  const _LoadingHome();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Loading expenses',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: AppSpacing.lg),
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.medium),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.large),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusNotice extends StatelessWidget {
  const _StatusNotice({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.danger : AppColors.warning;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.only(left: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.medium),
          border: Border.all(color: color),
        ),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: color,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              tooltip: 'Dismiss message',
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasAnyExpenses,
    required this.period,
    required this.onAdd,
  });

  final bool hasAnyExpenses;
  final String period;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasAnyExpenses
                      ? Icons.event_available_outlined
                      : Icons.receipt_long_outlined,
                  color: AppColors.accent,
                  size: 30,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                hasAnyExpenses
                    ? 'Nothing logged this $period'
                    : 'Ready when you are',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                hasAnyExpenses
                    ? 'Try another period, or add an expense now.'
                    : 'Add your first expense to start seeing useful patterns.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text(
                  hasAnyExpenses ? 'Add expense' : 'Add first expense',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
