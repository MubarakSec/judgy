import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:judgy/models/expense_state.dart';
import 'package:judgy/providers/expense_provider.dart';
import 'package:judgy/screens/home_screen.dart';
import 'package:judgy/services/quick_add_notifications.dart';
import 'package:judgy/theme/app_theme.dart';
import 'package:judgy/widgets/app_lock_gate.dart';
import 'package:provider/provider.dart';

import 'support/memory_repository.dart';

void main() {
  testWidgets(
    'waits for saved lock settings before showing history or quick add',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final loading = Completer<void>();
      final auth = Completer<bool>();
      final repo = MemoryRepository()
        ..loading = loading
        ..source = const ExpenseState(requireBiometric: true).encode();
      final p = ExpenseProvider(repository: repo);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: p,
          child: MaterialApp(
            theme: AppTheme.dark,
            builder: (_, child) =>
                AppLockGate(authenticate: () => auth.future, child: child!),
            home: const HomeScreen(openAddOnStart: true),
          ),
        ),
      );
      expect(find.text('Add first expense'), findsNothing);
      loading.complete();
      await p.initialized;
      await tester.pump();
      expect(find.text('Add first expense'), findsNothing);
      expect(find.text('Add an expense'), findsNothing);
      QuickAddNotifications.addRequests.value++;
      await tester.pump();
      expect(find.text('Add an expense'), findsNothing);
      auth.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('Add an expense'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'backgrounding hides open sheets and unlocking preserves the form',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final p = ExpenseProvider(
        repository: MemoryRepository()
          ..source = const ExpenseState(requireBiometric: true).encode(),
      );
      await p.initialized;
      var calls = 0;
      final secondAuth = Completer<bool>();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: p,
          child: MaterialApp(
            theme: AppTheme.dark,
            builder: (_, child) => AppLockGate(
              authenticate: () async => ++calls == 1 ? true : secondAuth.future,
              child: child!,
            ),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add first expense'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Expense name'),
        'Unsaved coffee',
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(find.text('Unsaved coffee'), findsNothing);
      expect(AppLockGate.sessionUnlocked.value, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Unsaved coffee'), findsNothing);
      secondAuth.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('Unsaved coffee'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
