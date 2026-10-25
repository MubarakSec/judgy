import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/expense_provider.dart';
import 'screens/home_screen.dart';
import 'services/quick_add_notifications.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final launchPayload = await QuickAddNotifications.initialize();
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ExpenseProvider())],
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
      home: HomeScreen(openAddOnStart: openAddOnStart),
    );
  }
}
