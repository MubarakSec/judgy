import 'package:shared_preferences/shared_preferences.dart';

/// A write publishes the complete logical state atomically. Imports also keep
/// the previous state in the same transaction, where the backend supports it.
abstract interface class ExpenseRepository {
  Future<String?> read();
  Future<void> write(String source, {String? recovery, bool reset = false});
  Future<String?> readRecovery();
  Future<Map<String, Object>> readLegacy();
}

/// Compatibility adapter used for legacy migration and lightweight unit tests.
class PreferencesExpenseRepository implements ExpenseRepository {
  static const stateKey = 'judgy_state_v2';
  static const recoveryKey = 'judgy_recovery_v2';
  static const legacyKeys = [
    'expenses',
    'isUSD',
    'exchangeRate',
    'monthlyBudget',
  ];

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(stateKey);
  @override
  Future<String?> readRecovery() async =>
      (await SharedPreferences.getInstance()).getString(recoveryKey);
  @override
  Future<Map<String, Object>> readLegacy() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final key in legacyKeys)
        if (prefs.get(key) != null) key: prefs.get(key)!,
    };
  }

  Future<void> clearLegacy() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [...legacyKeys, stateKey, recoveryKey]) {
      await prefs.remove(key);
    }
  }

  @override
  Future<void> write(
    String source, {
    String? recovery,
    bool reset = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (recovery != null && !await prefs.setString(recoveryKey, recovery)) {
      throw StateError('Recovery copy could not be saved.');
    }
    if (!await prefs.setString(stateKey, source)) {
      throw StateError('Write rejected.');
    }
    if (reset) {
      for (final key in [...legacyKeys, recoveryKey]) {
        await prefs.remove(key);
      }
    }
  }
}
