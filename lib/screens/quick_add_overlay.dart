import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/app_lock_gate.dart';
import 'add_expense_sheet.dart';

/// The translucent notification activity shows only the entry sheet. Closing
/// it finishes the activity and reveals the app the user was already using.
class QuickAddOverlay extends StatefulWidget {
  const QuickAddOverlay({super.key, this.onFinished});

  final Future<void> Function(String? message)? onFinished;

  @override
  State<QuickAddOverlay> createState() => _QuickAddOverlayState();
}

class _QuickAddOverlayState extends State<QuickAddOverlay> {
  static const _channel = MethodChannel('judgy/quick_add_overlay');
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    AppLockGate.sessionUnlocked.addListener(_maybeOpen);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOpen());
  }

  void _maybeOpen() {
    if (!mounted || _opened || !AppLockGate.sessionUnlocked.value) return;
    _opened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_showForm());
    });
  }

  Future<void> _showForm() async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      barrierLabel: 'Close quick add',
      builder: (_) => const AddExpenseSheet(),
    );
    if (!mounted) return;
    if (widget.onFinished != null) {
      await widget.onFinished!(message);
    } else {
      try {
        await _channel.invokeMethod<void>('finish', message);
      } on MissingPluginException {
        // Widget previews do not have an Android activity to finish.
      }
    }
  }

  @override
  void dispose() {
    AppLockGate.sessionUnlocked.removeListener(_maybeOpen);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Colors.transparent,
    body: SizedBox.expand(),
  );
}
