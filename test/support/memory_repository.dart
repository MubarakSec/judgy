import 'dart:async';
import 'package:judgy/repositories/expense_repository.dart';

class MemoryRepository implements ExpenseRepository {
  String? source;
  String? recovery;
  bool failWrites = false;
  Completer<void>? loading;
  @override
  Future<String?> read() async {
    await loading?.future;
    return source;
  }

  @override
  Future<void> write(
    String source, {
    String? recovery,
    bool reset = false,
  }) async {
    if (failWrites) throw StateError('disk full');
    this.source = source;
    if (reset) {
      this.recovery = null;
    } else if (recovery != null) {
      this.recovery = recovery;
    }
  }

  @override
  Future<Map<String, Object>> readLegacy() async => {};
  @override
  Future<String?> readRecovery() async => recovery;
}
