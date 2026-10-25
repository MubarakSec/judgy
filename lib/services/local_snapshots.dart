import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Seven rolling, app-private daily snapshots. Portable exports are separate.
class LocalSnapshots {
  LocalSnapshots({Future<Directory> Function()? directory})
    : _directory = directory ?? _defaultDirectory;
  final Future<Directory> Function() _directory;
  static Future<Directory> _defaultDirectory() async => Directory(
    '${(await getApplicationDocumentsDirectory()).path}/daily-backups',
  );

  Future<List<File>> files() async {
    final folder = await _directory();
    if (!await folder.exists()) return [];
    final result = await folder
        .list()
        .where(
          (entry) =>
              entry is File &&
              RegExp(r'/judgy-\d{4}-\d{2}-\d{2}\.json$').hasMatch(entry.path),
        )
        .cast<File>()
        .toList();
    result.sort((a, b) => b.path.compareTo(a.path));
    return result;
  }

  Future<void> saveIfDue(String source, DateTime now) async {
    final day =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final folder = await _directory();
    final target = File('${folder.path}/judgy-$day.json');
    if (await target.exists()) return;
    await folder.create(recursive: true);
    final temp = File('${target.path}.tmp');
    await temp.writeAsString(source, flush: true);
    await temp.rename(target.path);
    for (final old in (await files()).skip(7)) {
      await old.delete();
    }
  }

  Future<void> clear() async {
    for (final file in await files()) {
      await file.delete();
    }
  }

  static String dateLabel(File file) => file.path
      .split('/')
      .last
      .replaceFirst('judgy-', '')
      .replaceFirst('.json', '');
}
