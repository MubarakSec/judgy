import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/expense_provider.dart';
import 'screens/home_screen.dart';
import 'services/quick_add_notifications.dart';
import 'repositories/sqlite_expense_repository.dart';
import 'theme/app_theme.dart';
import 'widgets/app_lock_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final launchPayload = await QuickAddNotifications.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ExpenseProvider(repository: SqliteExpenseRepository()),
        ),
      ],
      child: JudgyApp(openAddOnStart: launchPayload == 'add'),
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
