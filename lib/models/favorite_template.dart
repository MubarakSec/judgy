/// A reusable entry that does not create a transaction until it is selected.
class FavoriteTemplate {
  const FavoriteTemplate({
    required this.id,
    required this.title,
    required this.amountMinorUnits,
    required this.currency,
    required this.category,
    required this.type,
  });

  final String id;
  final String title;
  final int amountMinorUnits;
  final String currency;
  final String category;
  final String type;

  double get amount => amountMinorUnits / 100;

  void validate() {
    if (id.trim().isEmpty ||
        id.length > 100 ||
        title.trim().isEmpty ||
        title.length > 80 ||
        category.trim().isEmpty ||
        category.length > 1000 ||
        amountMinorUnits <= 0 ||
        amountMinorUnits > 9007199254740991 ||
        (currency != 'USD' && currency != 'YER') ||
        (type != 'expense' && type != 'income')) {
      throw const FormatException('Invalid favorite.');
    }
  }

  Map<String, Object> toMap() => {
    'id': id,
    'title': title,
    'amountMinorUnits': amountMinorUnits,
    'currency': currency,
    'category': category,
    'type': type,
  };

  factory FavoriteTemplate.fromMap(Map<String, dynamic> map) {
    if (map['id'] is! String ||
        map['title'] is! String ||
        map['amountMinorUnits'] is! int ||
        map['currency'] is! String ||
        map['category'] is! String ||
        map['type'] is! String) {
      throw const FormatException('Invalid favorite.');
    }
    final favorite = FavoriteTemplate(
      id: map['id'] as String,
      title: map['title'] as String,
      amountMinorUnits: map['amountMinorUnits'] as int,
      currency: map['currency'] as String,
      category: map['category'] as String,
      type: map['type'] as String,
    );
    favorite.validate();
    return favorite;
  }

  FavoriteTemplate copyWith({
    String? title,
    int? amountMinorUnits,
    String? currency,
    String? category,
    String? type,
  }) => FavoriteTemplate(
    id: id,
    title: title ?? this.title,
    amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
    currency: currency ?? this.currency,
    category: category ?? this.category,
    type: type ?? this.type,
  );
}
