import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/expense_tile.dart';
import '../widgets/time_filter_tabs.dart';
import '../widgets/total_spent_card.dart';
import '../widgets/quick_entry_strip.dart';
import '../models/expense.dart';
import '../models/transaction_browser.dart';
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
  TransactionSort _sortMode = TransactionSort.newest;
  TransactionKind _kind = TransactionKind.all;

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
          unawaited(_refreshAfterResume());
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
      unawaited(_refreshAfterResume());
    }
  }

  Future<void> _refreshAfterResume() async {
    await _provider.refreshFromRepository();
    if (mounted && AppLockGate.sessionUnlocked.value) {
      await _provider.reconcileRecurring();
    }
  }

  Future<void> _openAddExpense(
    BuildContext context, {
    Expense? suggestion,
  }) async {
    if (_addSheetOpen || !_ready || !AppLockGate.sessionUnlocked.value) return;
    _addSheetOpen = true;
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierLabel: 'Close transaction form',
      builder: (_) => AddExpenseSheet(suggestion: suggestion),
    );
    _addSheetOpen = false;
    if (message == null || !context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

  Widget _buildSearch() => TextField(
    controller: _searchController,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: 'Search transactions',
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
          PopupMenuButton<TransactionSort>(
            tooltip: 'Sort transactions',
            initialValue: _sortMode,
            icon: Icon(
              Icons.sort_rounded,
              color: _sortMode == TransactionSort.newest
                  ? AppColors.textSecondary
                  : AppColors.accent,
            ),
            onSelected: (value) => setState(() => _sortMode = value),
            itemBuilder: (_) => [
              for (final entry in const {
                TransactionSort.newest: 'Newest first',
                TransactionSort.highestAmount: 'Highest amount',
                TransactionSort.name: 'Name A–Z',
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
    onChanged: (value) => setState(() => _searchQuery = value),
  );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final query = _searchQuery.trim();
    final browse = TransactionBrowser.browse(
      source: provider.filteredExpenses,
      kind: _kind,
      sort: _sortMode,
      query: query,
      isUsd: provider.isUSD,
      exchangeRate: provider.exchangeRate,
    );

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
                        if (query.isEmpty &&
                            provider.quickEntries.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          QuickEntryStrip(
                            onSelected: (entry) =>
                                _openAddExpense(context, suggestion: entry),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Transactions',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            Text(
                              '${browse.entries.length}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            IconButton(
                              tooltip: 'Insights',
                              onPressed: () => _openInsights(context),
                              icon: const Icon(Icons.insights_outlined),
                            ),
                            IconButton(
                              tooltip: 'Recurring transactions',
                              onPressed: () => _openRecurring(context),
                              icon: const Icon(Icons.repeat_outlined),
                            ),
                          ],
                        ),
                        SegmentedButton<TransactionKind>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: TransactionKind.all,
                              label: Text('All'),
                            ),
                            ButtonSegment(
                              value: TransactionKind.spent,
                              label: Text('Spent'),
                            ),
                            ButtonSegment(
                              value: TransactionKind.received,
                              label: Text('Received'),
                            ),
                          ],
                          selected: {_kind},
                          onSelectionChanged: (selection) =>
                              setState(() => _kind = selection.first),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _buildSearch(),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  sliver: browse.entries.isEmpty
                      ? SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyState(
                            hasAnyExpenses: provider.expenses.isNotEmpty,
                            message: query.isNotEmpty
                                ? 'No matches for "$query"'
                                : switch (_kind) {
                                    TransactionKind.spent => 'No spending here',
                                    TransactionKind.received =>
                                      'No received money here',
                                    TransactionKind.all =>
                                      switch (provider.timeFilter) {
                                        'Day' => 'Nothing logged today',
                                        'Week' => 'Nothing logged this week',
                                        'Custom' =>
                                          'Nothing logged in this range',
                                        _ => 'Nothing logged this month',
                                      },
                                  },
                          ),
                        )
                      : SliverList.builder(
                          itemCount: browse.rows.length,
                          itemBuilder: (_, index) {
                            final row = browse.rows[index];
                            if (row is TransactionDayRow) {
                              return _DayHeader(row: row);
                            }
                            return ExpenseTile(
                              expense: (row as TransactionEntryRow).entry,
                            );
                          },
                        ),
                ),
                if (browse.entries.isNotEmpty)
                  const SliverToBoxAdapter(child: SizedBox(height: 104)),
              ],
            ),
      floatingActionButton: !provider.isLoading
          ? FloatingActionButton.extended(
              onPressed: () => _openAddExpense(context),
              icon: const Icon(Icons.add),
              label: const Text('Add transaction'),
            )
          : null,
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.row});

  final TransactionDayRow row;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, AppSpacing.sm, 0, AppSpacing.xs),
    child: Row(
      children: [
        Expanded(
          child: Text(
            MaterialLocalizations.of(context).formatMediumDate(row.date),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Text(
          '${row.count} ${row.count == 1 ? 'entry' : 'entries'}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _LoadingHome extends StatelessWidget {
  const _LoadingHome();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Loading transactions',
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
  const _EmptyState({required this.hasAnyExpenses, required this.message});

  final bool hasAnyExpenses;
  final String message;

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
                hasAnyExpenses ? message : 'Ready when you are',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                hasAnyExpenses
                    ? 'Try another period, or add a transaction now.'
                    : 'Add your first transaction to start seeing useful patterns.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
