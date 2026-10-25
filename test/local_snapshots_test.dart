import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:judgy/services/local_snapshots.dart';

void main() {
  test('keeps seven daily snapshots and never replaces the same day', () async {
    final folder = await Directory.systemTemp.createTemp(
      'judgy-snapshots-test-',
    );
    addTearDown(() => folder.delete(recursive: true));
    final snapshots = LocalSnapshots(directory: () async => folder);
    for (var day = 1; day <= 10; day++) {
      await snapshots.saveIfDue('state $day', DateTime(2026, 10, day));
    }
    await snapshots.saveIfDue('should not replace', DateTime(2026, 10, 10));
    final files = await snapshots.files();
    expect(files, hasLength(7));
    expect(LocalSnapshots.dateLabel(files.first), '2026-10-10');
    expect(await files.first.readAsString(), 'state 10');
    await snapshots.clear();
    expect(await snapshots.files(), isEmpty);
  });
}
