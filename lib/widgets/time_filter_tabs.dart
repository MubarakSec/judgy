import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';

class TimeFilterTabs extends StatelessWidget {
  const TimeFilterTabs({super.key});

  static const _filters = ['Day', 'Week', 'Month', 'Custom'];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    return Semantics(
      label: 'Spending period',
      container: true,
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<String>(
          segments: _filters
              .map(
                (filter) =>
                    ButtonSegment<String>(value: filter, label: Text(filter)),
              )
              .toList(),
          selected: {provider.timeFilter},
          showSelectedIcon: false,
          expandedInsets: EdgeInsets.zero,
          onSelectionChanged: (selection) async {
            final filter = selection.first;
            if (filter != 'Custom') {
              provider.setTimeFilter(filter);
              return;
            }
            final now = DateTime.now();
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2000),
              lastDate: now.add(const Duration(days: 365)),
              initialDateRange: provider.customRangeStart != null &&
                      provider.customRangeEnd != null
                  ? DateTimeRange(
                      start: provider.customRangeStart!,
                      end: provider.customRangeEnd!,
                    )
                  : DateTimeRange(
                      start: now.subtract(const Duration(days: 7)),
                      end: now,
                    ),
            );
            if (picked != null) {
              provider.setCustomRange(picked.start, picked.end);
            } else if (provider.timeFilter != 'Custom') {
              // Keep previous filter if picker cancelled.
            } else {
              provider.setTimeFilter('Month');
            }
          },
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            ),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.selected)
                  ? AppColors.accentSoft
                  : AppColors.surface;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.selected)
                  ? AppColors.accent
                  : AppColors.textSecondary;
            }),
            side: WidgetStateProperty.resolveWith((states) {
              return BorderSide(
                color: states.contains(WidgetState.selected)
                    ? AppColors.accent
                    : AppColors.border,
              );
            }),
            textStyle: WidgetStateProperty.resolveWith((states) {
              return TextStyle(
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w700
                    : FontWeight.w500,
              );
            }),
          ),
        ),
      ),
    );
  }
}
