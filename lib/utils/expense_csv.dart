/// Minimal CSV codec for Judgy expenses.
class ExpenseCsv {
  const ExpenseCsv._();

  static String encode(List<Map<String, dynamic>> rows) {
    final buffer = StringBuffer();
    buffer.writeln(
      'id,title,amountCents,date,category,originalAmountMinorUnits,originalCurrency,exchangeRateAtEntry',
    );
    for (final row in rows) {
      buffer.writeln(
        [
          _field(row['id']),
          _field(row['title']),
          _field(row['amountCents']),
          _field(row['date']),
          _field(row['category']),
          _field(row['originalAmountMinorUnits']),
          _field(row['originalCurrency']),
          _field(row['exchangeRateAtEntry']),
        ].join(','),
      );
    }
    return buffer.toString();
  }

  static List<Map<String, dynamic>> decode(String source) {
    final lines = _splitRows(source.trim());
    if (lines.isEmpty) return const [];
    final header = lines.first.map((value) => value.trim()).toList();
    final rows = <Map<String, dynamic>>[];
    for (var i = 1; i < lines.length; i++) {
      final values = lines[i];
      if (values.isEmpty || (values.length == 1 && values.first.trim().isEmpty)) {
        continue;
      }
      final row = <String, dynamic>{};
      for (var j = 0; j < header.length && j < values.length; j++) {
        final key = header[j];
        final value = values[j].trim();
        if (value.isEmpty) continue;
        switch (key) {
          case 'amountCents':
          case 'originalAmountMinorUnits':
            row[key] = int.tryParse(value) ?? value;
            break;
          case 'exchangeRateAtEntry':
            row[key] = double.tryParse(value) ?? value;
            break;
          default:
            row[key] = value;
        }
      }
      rows.add(row);
    }
    return rows;
  }

  static String _field(dynamic value) {
    if (value == null) return '';
    final text = value.toString();
    if (text.contains(',') || text.contains('"') || text.contains('\n')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  static List<List<String>> _splitRows(String source) {
    final rows = <List<String>>[];
    final current = <StringBuffer>[];
    var inQuotes = false;
    var field = StringBuffer();
    var rowStarted = false;

    void finishField() {
      current.add(field);
      field = StringBuffer();
    }

    void finishRow() {
      if (!rowStarted && current.isEmpty) return;
      rows.add(current.map((buffer) => buffer.toString()).toList());
      current.clear();
      rowStarted = false;
    }

    for (var i = 0; i < source.length; i++) {
      final char = source[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < source.length && source[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(char);
        }
      } else {
        if (char == '"') {
          inQuotes = true;
          rowStarted = true;
        } else if (char == ',') {
          finishField();
          rowStarted = true;
        } else if (char == '\n') {
          finishField();
          finishRow();
        } else if (char == '\r') {
          // Ignore CR.
        } else {
          field.write(char);
          rowStarted = true;
        }
      }
    }
    if (rowStarted || field.isNotEmpty || current.isNotEmpty) {
      finishField();
      finishRow();
    }
    return rows;
  }
}
