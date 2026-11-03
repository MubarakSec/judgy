import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:judgy/models/cash_flow_history.dart';
import 'package:judgy/theme/app_theme.dart';
import 'package:judgy/widgets/cash_flow_history_chart.dart';

void main() {
  testWidgets('tapping a month shows exact spending, income, and net', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final months = [
      for (var index = 1; index <= 6; index++)
        MonthlyCashFlow(
          month: DateTime(2026, index),
          spentCents: index == 5 ? 1200 : 0,
          receivedCents: index == 5 ? 2000 : 0,
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: CashFlowHistoryChart(
              months: months,
              isUsd: true,
              exchangeRate: 540,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Jun 2026'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cash-flow-2026-5')));
    await tester.pumpAndSettle();
    expect(find.text('May 2026'), findsOneWidget);
    expect(find.text(r'$12.00'), findsOneWidget);
    expect(find.text(r'$20.00'), findsOneWidget);
    expect(find.text(r'+$8.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty history has a clear state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: CashFlowHistoryChart(
            months: [
              MonthlyCashFlow(
                month: DateTime(2026, 11),
                spentCents: 0,
                receivedCents: 0,
              ),
            ],
            isUsd: true,
            exchangeRate: 540,
          ),
        ),
      ),
    );
    expect(
      find.text('No transactions in the last six months.'),
      findsOneWidget,
    );
  });
}
