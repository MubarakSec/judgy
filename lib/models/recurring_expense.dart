import 'dart:convert';

class RecurringExpense {
  const RecurringExpense({
    required this.id,
    required this.title,
    required this.amountCents,
    required this.category,
    required this.dayOfMonth,
    this.lastApplied,
  });

  final String id;
  final String title;
  final int amountCents;
  final String category;
  final int dayOfMonth;
  final DateTime? lastApplied;

  void validate() {
    if (id.trim().isEmpty ||
        title.trim().isEmpty ||
        category.trim().isEmpty ||
        amountCents <= 0 ||
        amountCents > 9007199254740991 ||
        dayOfMonth < 1 ||
        dayOfMonth > 31) {
      throw const FormatException(
        'Enter a valid recurring name, amount, and day (1–31).',
      );
    }
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'title': title,
    'amountCents': amountCents,
    'category': category,
    'dayOfMonth': dayOfMonth,
    if (lastApplied != null) 'lastApplied': lastApplied!.toIso8601String(),
  };

  factory RecurringExpense.fromMap(Map<String, dynamic> map) {
    final rawLast = map['lastApplied'];
    if (map['id'] is! String ||
        map['title'] is! String ||
        map['category'] is! String ||
        map['amountCents'] is! int ||
        map['dayOfMonth'] is! int ||
        (rawLast != null &&
            (rawLast is! String || DateTime.tryParse(rawLast) == null))) {
      throw const FormatException('Invalid recurring expense.');
    }
    final result = RecurringExpense(
      id: (map['id'] as String).trim(),
      title: (map['title'] as String).trim(),
      amountCents: map['amountCents'] as int,
      category: (map['category'] as String).trim(),
      dayOfMonth: map['dayOfMonth'] as int,
      lastApplied: rawLast == null ? null : DateTime.parse(rawLast as String),
    );
    result.validate();
    return result;
  }

  String toJson() => jsonEncode(toMap());

  factory RecurringExpense.fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException(
        'Recurring expense JSON must contain an object.',
      );
    }
    return RecurringExpense.fromMap(Map<String, dynamic>.from(decoded));
  }

  RecurringExpense copyWith({DateTime? lastApplied}) {
    return RecurringExpense(
      id: id,
      title: title,
      amountCents: amountCents,
      category: category,
      dayOfMonth: dayOfMonth,
      lastApplied: lastApplied ?? this.lastApplied,
    );
  }
}
