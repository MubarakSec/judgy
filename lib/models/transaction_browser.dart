import '../models/expense.dart';
import '../utils/currency_formatter.dart';

enum TransactionKind { all, spent, received }

enum TransactionSort { newest, highestAmount, name }

sealed class TransactionListRow {
  const TransactionListRow();
}

class TransactionDayRow extends TransactionListRow {
  const TransactionDayRow(this.date, this.count);
  final DateTime date;
  final int count;
}

class TransactionEntryRow extends TransactionListRow {
  const TransactionEntryRow(this.entry);
  final Expense entry;
}

class TransactionBrowseResult {
  const TransactionBrowseResult({required this.entries, required this.rows});

  final List<Expense> entries;
  final List<TransactionListRow> rows;
}

abstract final class TransactionBrowser {
  static TransactionBrowseResult browse({
    required Iterable<Expense> source,
    required TransactionKind kind,
    required TransactionSort sort,
    required String query,
    required bool isUsd,
    required double exchangeRate,
  }) {
    final term = query.trim().toLowerCase();
    final entries = source.where((entry) {
      if (kind == TransactionKind.spent && entry.isIncome) return false;
      if (kind == TransactionKind.received && !entry.isIncome) return false;
      if (term.isEmpty) return true;
      return entry.title.toLowerCase().contains(term) ||
          entry.category.toLowerCase().contains(term) ||
          (entry.note?.toLowerCase().contains(term) ?? false) ||
          CurrencyFormatter.displayFromUsdCents(
            usdCents: entry.amountCents,
            isUsd: isUsd,
            exchangeRate: exchangeRate,
          ).toLowerCase().contains(term);
    }).toList();

    switch (sort) {
      case TransactionSort.newest:
        entries.sort((a, b) {
          final byDate = b.date.compareTo(a.date);
          return byDate == 0 ? a.id.compareTo(b.id) : byDate;
        });
      case TransactionSort.highestAmount:
        entries.sort((a, b) {
          final byAmount = b.amountCents.compareTo(a.amountCents);
          return byAmount == 0 ? b.date.compareTo(a.date) : byAmount;
        });
      case TransactionSort.name:
        entries.sort((a, b) {
          final byName = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          return byName == 0 ? b.date.compareTo(a.date) : byName;
        });
    }

    final rows = <TransactionListRow>[];
    if (sort == TransactionSort.newest) {
      var index = 0;
      while (index < entries.length) {
        final current = entries[index].date;
        var end = index + 1;
        while (end < entries.length && _sameDay(current, entries[end].date)) {
          end++;
        }
        rows.add(
          TransactionDayRow(
            DateTime(current.year, current.month, current.day),
            end - index,
          ),
        );
        for (var offset = index; offset < end; offset++) {
          rows.add(TransactionEntryRow(entries[offset]));
        }
        index = end;
      }
    } else {
      rows.addAll(entries.map(TransactionEntryRow.new));
    }
    return TransactionBrowseResult(
      entries: List.unmodifiable(entries),
      rows: List.unmodifiable(rows),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
