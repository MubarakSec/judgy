import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';

/// Wraps the Navigator, so locking also hides open sheets and dialogs while
/// preserving unsaved forms and native file-picker operations.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child, this.authenticate});
  final Widget child;
  final Future<bool> Function()? authenticate;
  static final sessionUnlocked = ValueNotifier<bool>(false);
  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  final _auth = LocalAuthentication();
  late final ExpenseProvider _provider;
  bool _ready = false;
  bool _unlocked = false;
  bool _authenticating = false;
  bool _lastSetting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    AppLockGate.sessionUnlocked.value = false;
    _provider = context.read<ExpenseProvider>();
    _provider.addListener(_settingsChanged);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await _provider.initialized;
    if (!mounted) return;
    _lastSetting = _provider.requireBiometric;
    setState(() {
      _ready = true;
      _unlocked = !_lastSetting;
    });
    _publish();
    if (_lastSetting) unawaited(_authenticate());
  }

  void _publish() {
    AppLockGate.sessionUnlocked.value =
        _ready && (!_provider.requireBiometric || _unlocked);
  }

  void _settingsChanged() {
    if (!_ready || _lastSetting == _provider.requireBiometric) return;
    _lastSetting = _provider.requireBiometric;
    setState(() {
      _unlocked = !_lastSetting;
      _error = null;
    });
    _publish();
    if (_lastSetting) unawaited(_authenticate());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_ready || _authenticating) return;
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) &&
        _provider.requireBiometric) {
      setState(() => _unlocked = false);
      _publish();
    }
    if (state == AppLifecycleState.resumed &&
        _provider.requireBiometric &&
        !_unlocked) {
      unawaited(_authenticate());
    }
  }

  Future<void> _authenticate() async {
    if (_authenticating || !mounted) return;
    setState(() {
      _authenticating = true;
      _error = null;
    });
    try {
      final ok =
          await (widget.authenticate?.call() ??
              _auth.authenticate(
                localizedReason: 'Unlock your private expense history',
              ));
      if (!mounted) return;
      setState(() {
        _unlocked = ok;
        _error = ok
            ? null
            : 'Unlock was cancelled. Try again when you’re ready.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Device unlock is unavailable. Check your Android screen lock and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _authenticating = false);
        _publish();
      }
    }
  }

  @override
  void dispose() {
    _provider.removeListener(_settingsChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locked = !_ready || (_provider.requireBiometric && !_unlocked);
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: locked,
          child: ExcludeFocus(
            excluding: locked,
            child: TickerMode(enabled: !locked, child: widget.child),
          ),
        ),
        if (locked)
          Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: !_ready
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_outline_rounded, size: 40),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Your spending stays private',
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.md,
                              ),
                              child: Text(_error!, textAlign: TextAlign.center),
                            ),
                          const SizedBox(height: AppSpacing.lg),
                          FilledButton(
                            onPressed: _authenticating ? null : _authenticate,
                            child: Text(
                              _authenticating ? 'Unlocking…' : 'Unlock Judgy',
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
      ],
    );
  }
}
