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
    return RecurringExpense(
      id: (map['id'] as String?)?.trim().isNotEmpty == true
          ? map['id'] as String
          : DateTime.now().microsecondsSinceEpoch.toString(),
      title: (map['title'] as String?)?.trim().isNotEmpty == true
          ? (map['title'] as String).trim()
          : 'Recurring expense',
      amountCents: (map['amountCents'] as num?)?.toInt() ?? 0,
      category: (map['category'] as String?)?.trim().isNotEmpty == true
          ? (map['category'] as String).trim()
          : 'Other',
      dayOfMonth: ((map['dayOfMonth'] as num?)?.toInt() ?? 1).clamp(1, 31),
      lastApplied: rawLast is String ? DateTime.tryParse(rawLast) : null,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory RecurringExpense.fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Recurring expense JSON must contain an object.');
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
