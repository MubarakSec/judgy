/// Strict CSV codec. Text is escaped for spreadsheets and restored losslessly
/// using the explicit encoding column on Judgy-generated files.
class ExpenseCsv {
  const ExpenseCsv._();
  static const _columns = [
    'id',
    'title',
    'amountCents',
    'date',
    'category',
    'note',
    'originalAmountMinorUnits',
    'originalCurrency',
    'exchangeRateAtEntry',
    'textEncoding',
  ];
  static const _textColumns = {
    'id',
    'title',
    'category',
    'note',
    'originalCurrency',
  };

  static String encode(List<Map<String, dynamic>> rows) {
    final buffer = StringBuffer()..writeln(_columns.join(','));
    for (final row in rows) {
      buffer.writeln(
        _columns
            .map((key) {
              if (key == 'textEncoding') return 'apostrophe-v1';
              var text = row[key]?.toString() ?? '';
              if (_textColumns.contains(key) &&
                  RegExp(r"^[=+@\-\t\r']").hasMatch(text)) {
                text = "'$text";
              }
              return _field(text);
            })
            .join(','),
      );
    }
    return buffer.toString();
  }

  static List<Map<String, dynamic>> decode(String source) {
    if (source.length > 10 * 1024 * 1024) {
      throw const FormatException('CSV exceeds 10 MB.');
    }
    final lines = _splitRows(source.replaceFirst(RegExp(r'^\uFEFF'), ''));
    if (lines.isEmpty) throw const FormatException('CSV is empty.');
    final header = lines.first.map((v) => v.trim()).toList();
    if (header.toSet().length != header.length ||
        !{
          'id',
          'title',
          'amountCents',
          'date',
          'category',
        }.every(header.contains)) {
      throw const FormatException(
        'CSV must include id, title, amountCents, date, and category.',
      );
    }
    final rows = <Map<String, dynamic>>[];
    for (var i = 1; i < lines.length; i++) {
      final values = lines[i];
      if (values.every((v) => v.trim().isEmpty)) continue;
      if (values.length != header.length) {
        throw FormatException('Wrong column count on row ${i + 1}.');
      }
      final raw = {
        for (var j = 0; j < header.length; j++) header[j]: values[j],
      };
      final escaped = raw['textEncoding'] == 'apostrophe-v1';
      final row = <String, dynamic>{};
      for (final key in header) {
        if (key == 'textEncoding') continue;
        var value = raw[key]!;
        if (escaped &&
            _textColumns.contains(key) &&
            value.startsWith("'") &&
            value.length > 1 &&
            RegExp(r"^[=+@\-\t\r']").hasMatch(value.substring(1))) {
          value = value.substring(1);
        }
        if (value.isEmpty) continue;
        row[key] = switch (key) {
          'amountCents' ||
          'originalAmountMinorUnits' => int.tryParse(value.trim()) ?? value,
          'exchangeRateAtEntry' => double.tryParse(value.trim()) ?? value,
          _ => value,
        };
      }
      rows.add(row);
    }
    return rows;
  }

  static String _field(String value) => value.contains(RegExp('[,"\n\r]'))
      ? '"${value.replaceAll('"', '""')}"'
      : value;

  static List<List<String>> _splitRows(String source) {
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var quoted = false;
    var closed = false;
    for (var i = 0; i < source.length; i++) {
      final char = source[i];
      if (quoted) {
        if (char == '"') {
          if (i + 1 < source.length && source[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            quoted = false;
            closed = true;
          }
        } else {
          field.write(char);
        }
      } else if (char == ',' || char == '\n' || char == '\r') {
        row.add(field.toString());
        field = StringBuffer();
        closed = false;
        if (char != ',') {
          rows.add(row);
          row = [];
          if (char == '\r' && i + 1 < source.length && source[i + 1] == '\n') {
            i++;
          }
        }
      } else if (char == '"' && field.isEmpty && !closed) {
        quoted = true;
      } else {
        if (closed || char == '"') {
          throw const FormatException('Malformed CSV quoting.');
        }
        field.write(char);
      }
    }
    if (quoted) throw const FormatException('Unclosed CSV quote.');
    if (field.isNotEmpty || row.isNotEmpty || closed) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }
}
