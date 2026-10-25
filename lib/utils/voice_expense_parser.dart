import 'currency_formatter.dart';

/// Lightweight parser for spoken expense entries such as
/// "وفاء زيادة 200" or "وفاء ناقص 300".
class VoiceExpenseParser {
  const VoiceExpenseParser._();

  static const _ignoredWords = <String>{
    'زيادة',
    'ناقص',
    'plus',
    'minus',
    'add',
    'remove',
    'spent',
    'for',
    'on',
  };

  static ({String title, double? amount}) parse(String spoken) {
    final normalized = spoken;
    final tokens = normalized.trim().split(RegExp(r'\s+'));
    double? amount;
    final titleTokens = <String>[];
    for (final token in tokens) {
      final parsed = CurrencyFormatter.parseAmount(token);
      if (parsed != null && amount == null) {
        amount = parsed;
      } else if (!_ignoredWords.contains(token)) {
        titleTokens.add(token);
      }
    }
    final title = titleTokens.join(' ').trim();
    return (title: title.isEmpty ? 'Voice entry' : title, amount: amount);
  }
}
