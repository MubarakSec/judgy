import 'currency_formatter.dart';

enum VoiceIntent { expense, refund, income }

class VoiceExpenseDraft {
  const VoiceExpenseDraft({
    required this.transcript,
    required this.title,
    required this.amount,
    required this.currency,
    required this.date,
    required this.category,
    required this.intent,
    required this.issues,
  });
  final String transcript;
  final String title;
  final double? amount;
  final String? currency;
  final DateTime date;
  final String category;
  final VoiceIntent intent;
  final List<String> issues;
  bool get canApply =>
      amount != null &&
      amount!.isFinite &&
      amount! > 0 &&
      issues.isEmpty &&
      intent == VoiceIntent.expense;
}

/// Deterministic parsing keeps transcript interpretation on the device. The
/// recognizer may return digits or number words; neither is assumed.
class VoiceExpenseParser {
  const VoiceExpenseParser._();
  static const _numbers = <String, int>{
    'zero': 0,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
    'twenty': 20,
    'thirty': 30,
    'forty': 40,
    'fifty': 50,
    'sixty': 60,
    'seventy': 70,
    'eighty': 80,
    'ninety': 90,
    'صفر': 0,
    'واحد': 1,
    'احد': 1,
    'احدي': 1,
    'اثنا': 2,
    'اثني': 2,
    'ثنتين': 2,
    'واحده': 1,
    'اثنين': 2,
    'اثنان': 2,
    'اثنتين': 2,
    'ثلاث': 3,
    'ثلاثه': 3,
    'اربع': 4,
    'اربعه': 4,
    'خمس': 5,
    'خمسه': 5,
    'ست': 6,
    'سته': 6,
    'سبع': 7,
    'سبعه': 7,
    'ثمان': 8,
    'ثمانيه': 8,
    'تسع': 9,
    'تسعه': 9,
    'عشر': 10,
    'عشره': 10,
    'عشرين': 20,
    'عشرون': 20,
    'ثلاثين': 30,
    'ثلاثون': 30,
    'اربعين': 40,
    'اربعون': 40,
    'خمسين': 50,
    'خمسون': 50,
    'ستين': 60,
    'ستون': 60,
    'سبعين': 70,
    'سبعون': 70,
    'ثمانين': 80,
    'ثمانون': 80,
    'تسعين': 90,
    'تسعون': 90,
    'ميتين': 200,
    'مئتين': 200,
    'مائتين': 200,
    'مئتان': 200,
    'ثلاثمئه': 300,
    'ثلاثمائه': 300,
    'اربعمئه': 400,
    'اربعمائه': 400,
    'خمسمئه': 500,
    'خمسمائه': 500,
    'ستمئه': 600,
    'ستمائه': 600,
    'سبعمئه': 700,
    'سبعمائه': 700,
    'ثمانمئه': 800,
    'ثمانمائه': 800,
    'تسعمئه': 900,
    'تسعمائه': 900,
    'الفين': 2000,
    'الفان': 2000,
  };
  static const _scales = <String, int>{
    'hundred': 100,
    'مئه': 100,
    'مائه': 100,
    'ميه': 100,
    'thousand': 1000,
    'الف': 1000,
    'الاف': 1000,
    'million': 1000000,
    'مليون': 1000000,
  };
  static const _fillers = {
    'زياده',
    'plus',
    'add',
    'spent',
    'spend',
    'paid',
    'pay',
    'for',
    'on',
    'at',
    'i',
    'a',
    'an',
    'the',
    'and',
    'دفعت',
    'صرفت',
    'اشتريت',
    'اضف',
    'اضافه',
    'علي',
    'على',
    'في',
    'عند',
    'مقابل',
    'مبلغ',
    'بمبلغ',
    'و',
  };
  static const _refund = {
    'ناقص',
    'minus',
    'remove',
    'refund',
    'refunded',
    'استرجاع',
    'مرتجع',
  };
  static const _income = {
    'income',
    'salary',
    'earned',
    'received',
    'دخل',
    'راتب',
    'استلمت',
  };
  static const _usd = {'usd', 'dollar', 'dollars', 'دولار', 'دولارات', '\$'};
  static const _yer = {
    'yer',
    'riyal',
    'riyals',
    'ريال',
    'ريالات',
    'يمني',
    'يمنيه',
  };
  static const _unsupported = {
    'sar',
    'saudi',
    'سعودي',
    'سعوديه',
    'eur',
    'euro',
    'euros',
    'يورو',
  };

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[\u064B-\u065F\u0670\u0640]'), '')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي');
  static String _numberToken(String token) {
    if (token.startsWith('و') && token.length > 1) {
      final rest = token.substring(1);
      if (_numbers.containsKey(rest) || _scales.containsKey(rest)) return rest;
    }
    return token;
  }

  static VoiceExpenseDraft parse(String spoken, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final normalized = CurrencyFormatter.normalizeDigits(spoken);
    final originals = RegExp(
      r'[+-]?\d+(?:[.,]\d+)*|[a-zA-Z\u0621-\u064A\u064B-\u065F\u0670]+|\$',
    ).allMatches(normalized).map((m) => m.group(0)!).toList();
    final tokens = originals.map(_normalize).toList();
    final used = <int>{};
    final amounts = <double>[];
    final currencies = <String>{};
    final issues = <String>[];
    var intent = VoiceIntent.expense;
    var date = current;
    var yesterday = false;
    var today = false;
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (_refund.contains(token)) {
        intent = VoiceIntent.refund;
        used.add(i);
      }
      if (_income.contains(token)) {
        intent = VoiceIntent.income;
        used.add(i);
      }
      if (_usd.contains(token)) {
        currencies.add('USD');
        used.add(i);
      }
      if (_yer.contains(token)) {
        currencies.add('YER');
        used.add(i);
      }
      if (_unsupported.contains(token)) {
        issues.add('Only USD and Yemeni riyal (YER) are supported.');
        used.add(i);
      }
      if (token == 'today' || token == 'اليوم') {
        today = true;
        used.add(i);
      }
      if (token == 'yesterday' ||
          token == 'امس' ||
          token == 'البارح' ||
          token == 'البارحه') {
        yesterday = true;
        used.add(i);
      }
    }
    if (yesterday && today) {
      issues.add('More than one date was heard. Enter the date manually.');
    }
    if (yesterday) {
      date = DateTime(current.year, current.month, current.day - 1);
    }

    for (var i = 0; i < tokens.length; i++) {
      if (used.contains(i)) continue;
      final result = _readNumber(tokens, i);
      if (result == null) continue;
      amounts.add(result.value);
      for (var j = i; j < result.end; j++) {
        used.add(j);
      }
      i = result.end - 1;
    }
    if (amounts.length > 1) {
      issues.add(
        'More than one amount was heard. Record one expense at a time.',
      );
    }
    if (currencies.length > 1) {
      issues.add('Both USD and YER were heard. Choose one currency manually.');
    }
    final amount = amounts.length == 1 ? amounts.single : null;
    if (amount == null) {
      issues.add(
        'No single clear amount was heard. Try “coffee twenty riyals”.',
      );
    }
    if (amount != null && amount <= 0) {
      issues.add('Expenses need a positive amount.');
      if (amount < 0) intent = VoiceIntent.refund;
    }
    if (intent != VoiceIntent.expense) {
      issues.add(
        'This sounds like ${intent == VoiceIntent.refund ? 'a refund or subtraction' : 'income'}. Judgy records spending only; this entry has not been applied.',
      );
    }
    final title = [
      for (var i = 0; i < tokens.length; i++)
        if (!used.contains(i) && !_fillers.contains(tokens[i])) originals[i],
    ].join(' ').trim();
    final lowerTitle = _normalize(title);
    var category = 'Other';
    const categoryWords = {
      'Coffee': ['coffee', 'cafe', 'قهوه', 'كافي'],
      'Food': [
        'food',
        'lunch',
        'dinner',
        'breakfast',
        'groceries',
        'غداء',
        'عشاء',
        'فطور',
        'اكل',
        'بقاله',
        'مطعم',
      ],
      'Shopping': ['shopping', 'clothes', 'ملابس', 'تسوق'],
      'Subscriptions': [
        'subscription',
        'netflix',
        'spotify',
        'اشتراك',
        'نتفلكس',
      ],
    };
    for (final entry in categoryWords.entries) {
      if (entry.value.any(lowerTitle.contains)) {
        category = entry.key;
        break;
      }
    }
    return VoiceExpenseDraft(
      transcript: spoken,
      title: title.isEmpty ? 'Voice entry' : title,
      amount: amount,
      currency: currencies.length == 1 ? currencies.single : null,
      date: date,
      category: category,
      intent: intent,
      issues: List.unmodifiable(issues.toSet()),
    );
  }

  static ({double value, int end})? _readNumber(
    List<String> tokens,
    int start,
  ) {
    var current = 0.0;
    var total = 0.0;
    var i = start;
    var count = 0;
    var previous = -1.0;
    var previousDigits = false;
    while (i < tokens.length) {
      final raw = tokens[i];
      final token = _numberToken(raw);
      if ((token == 'and' || token == 'و') &&
          count > 0 &&
          i + 1 < tokens.length &&
          (_numbers.containsKey(_numberToken(tokens[i + 1])) ||
              _scales.containsKey(_numberToken(tokens[i + 1])))) {
        i++;
        continue;
      }
      if ((token == 'point' || token == 'فاصله') && count > 0) {
        final digits = StringBuffer();
        var j = i + 1;
        while (j < tokens.length) {
          final word = _numberToken(tokens[j]);
          final n = _numbers[word] ?? int.tryParse(word);
          if (n == null || n < 0 || n > 9) break;
          digits.write(n);
          j++;
        }
        if (digits.isEmpty) break;
        return (value: total + current + double.parse('0.$digits'), end: j);
      }
      final scale = _scales[token];
      if (scale != null) {
        if (scale == 100) {
          current = (current == 0 ? 1.0 : current) * scale;
        } else {
          total += (current == 0 ? 1.0 : current) * scale;
          current = 0;
        }
        previous = scale.toDouble();
        previousDigits = false;
        count++;
        i++;
        continue;
      }
      final numeric = CurrencyFormatter.parseAmount(token);
      final value = _numbers[token]?.toDouble() ?? numeric;
      if (value == null) break;
      final digits = numeric != null;
      if (count > 0 &&
          (digits ||
              previousDigits ||
              (previous < 20 && value < 10) ||
              (previous >= 20 &&
                  previous < 100 &&
                  value >= 20 &&
                  value < 100))) {
        break;
      }
      current += value;
      previous = value;
      previousDigits = digits;
      count++;
      i++;
    }
    return count == 0 ? null : (value: total + current, end: i);
  }
}
