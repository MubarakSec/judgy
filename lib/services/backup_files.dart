import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';

class BackupFiles {
  const BackupFiles();
  Future<bool> share(String source, {bool csv = false}) async {
    final extension = csv ? 'csv' : 'json';
    final name =
        'judgy-${DateTime.now().toIso8601String().replaceAll(':', '-')}.$extension';
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            utf8.encode(source),
            mimeType: csv ? 'text/csv' : 'application/json',
          ),
        ],
        fileNameOverrides: [name],
        title: csv ? 'Judgy expenses' : 'Judgy backup',
      ),
    );
    return result.status == ShareResultStatus.success;
  }

  Future<({String source, bool csv, String name})?> pick() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Judgy backup or CSV',
          extensions: ['json', 'csv'],
          mimeTypes: [
            'application/json',
            'text/csv',
            'text/comma-separated-values',
            'text/plain',
          ],
        ),
      ],
    );
    if (file == null) return null;
    if (await file.length() > 10 * 1024 * 1024) {
      throw const FormatException('Choose a backup smaller than 10 MB.');
    }
    return (
      source: await file.readAsString(),
      csv: file.name.toLowerCase().endsWith('.csv'),
      name: file.name,
    );
  }
}
