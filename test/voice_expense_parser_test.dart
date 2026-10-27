import 'package:flutter_test/flutter_test.dart';
import 'package:judgy/utils/voice_expense_parser.dart';

void main() {
  final now = DateTime(2026, 10, 25, 12);
  test('Arabic digits and add wording preserve the title', () {
    final draft = VoiceExpenseParser.parse('وفاء زيادة ٢٠٠');
    expect(draft.title, 'وفاء');
    expect(draft.amount, 200);
    expect(draft.canApply, isTrue);
  });
  test(
    'understands Arabic number words, currency, category, and yesterday',
    () {
      final draft = VoiceExpenseParser.parse(
        'دفعت قهوة مئتين وخمسين ريال أمس',
        now: now,
      );
      expect(draft.title, 'قهوة');
      expect(draft.amount, 250);
      expect(draft.currency, 'YER');
      expect(draft.category, 'Coffee');
      expect(draft.date, DateTime(2026, 10, 24));
      expect(draft.canApply, isTrue);
    },
  );
  test('English compound numbers and decimal words', () {
    final draft = VoiceExpenseParser.parse(
      'Coffee spent twenty five point five dollars today',
      now: now,
    );
    expect(draft.title, 'Coffee');
    expect(draft.amount, 25.5);
    expect(draft.currency, 'USD');
    expect(draft.canApply, isTrue);
  });
  test('supports numeric thousands and Arabic decimal words', () {
    expect(VoiceExpenseParser.parse('تسوق 2 ألف ريال').amount, 2000);
    expect(VoiceExpenseParser.parse('قهوة عشرين فاصلة خمسة ريال').amount, 20.5);
    expect(
      VoiceExpenseParser.parse('food one hundred and twenty dollars').amount,
      120,
    );
  });
  test('understands Arabic preposition prefixes and recognizer variants', () {
    final coffee = VoiceExpenseParser.parse('خهوة بعشرين ريالاً', now: now);
    expect(coffee.title, 'خهوة');
    expect(coffee.amount, 20);
    expect(coffee.currency, 'YER');
    expect(coffee.category, 'Coffee');
    expect(coffee.canApply, isTrue);

    final lunch = VoiceExpenseParser.parse('غداء بخمسة دولارات', now: now);
    expect(lunch.amount, 5);
    expect(lunch.currency, 'USD');
    expect(lunch.category, 'Food');
    expect(lunch.canApply, isTrue);

    expect(VoiceExpenseParser.parse('قهوة 20 بالريال').currency, 'YER');
  });
  test('rejects subtraction, refunds, income, and negative numbers', () {
    for (final phrase in [
      'وفاء ناقص 300',
      'refund coffee 4 dollars',
      'salary 1000 dollars',
      'coffee -20',
    ]) {
      final draft = VoiceExpenseParser.parse(phrase);
      expect(draft.canApply, isFalse, reason: phrase);
      expect(draft.issues, isNotEmpty);
    }
  });
  test('does not silently choose between multiple amounts or currencies', () {
    expect(VoiceExpenseParser.parse('coffee 20 and food 30').amount, isNull);
    expect(
      VoiceExpenseParser.parse('coffee 20 dollars ريال').canApply,
      isFalse,
    );
    expect(VoiceExpenseParser.parse('قهوة 20 ريال سعودي').canApply, isFalse);
  });
  test(
    'missing amounts stay absent and punctuation does not pollute title',
    () {
      expect(VoiceExpenseParser.parse('coffee please').amount, isNull);
      expect(
        VoiceExpenseParser.parse('Coffee spent 4.50 dollars.').title,
        'Coffee',
      );
      expect(VoiceExpenseParser.parse('12.50').title, 'Voice entry');
    },
  );
}
