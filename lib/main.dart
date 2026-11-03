import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/expense_provider.dart';
import 'screens/home_screen.dart';
import 'screens/quick_add_overlay.dart';
import 'services/quick_add_notifications.dart';
import 'repositories/sqlite_expense_repository.dart';
import 'theme/app_theme.dart';
import 'widgets/app_lock_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final provider = ExpenseProvider(repository: SqliteExpenseRepository());
  await provider.initialized;
  final launchPayload = await QuickAddNotifications.initialize(
    showQuickAdd: false,
  );
  await QuickAddNotifications.syncQuickAdd(provider.showQuickAddNotification);
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider.value(value: provider)],
      child: JudgyApp(openAddOnStart: launchPayload == 'add'),
    ),
  );
}

@pragma('vm:entry-point')
Future<void> quickAddMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await QuickAddNotifications.initialize(showQuickAdd: false);
  runApp(
    ChangeNotifierProvider(
      create: (_) => ExpenseProvider(repository: SqliteExpenseRepository()),
      child: const QuickAddApp(),
    ),
  );
}

class JudgyApp extends StatelessWidget {
  const JudgyApp({super.key, this.openAddOnStart = false});

  final bool openAddOnStart;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Judgy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      builder: (context, child) => AppLockGate(child: child!),
      home: HomeScreen(openAddOnStart: openAddOnStart),
    );
  }
}

class QuickAddApp extends StatelessWidget {
  const QuickAddApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Quick add',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark.copyWith(scaffoldBackgroundColor: Colors.transparent),
    builder: (context, child) => AppLockGate(child: child!),
    home: const QuickAddOverlay(),
  );
}
