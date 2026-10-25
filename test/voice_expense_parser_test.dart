import 'package:flutter_test/flutter_test.dart';
import 'package:judgy/utils/voice_expense_parser.dart';

void main() {
  test('parses Arabic voice entry', () {
    final result = VoiceExpenseParser.parse('وفاء زيادة 200');
    expect(result.title, 'وفاء');
    expect(result.amount, 200);
  });

  test('parses English voice entry', () {
    final result = VoiceExpenseParser.parse('Coffee spent 4.50');
    expect(result.title, 'Coffee');
    expect(result.amount, 4.5);
  });

  test('falls back to Voice entry when no title', () {
    final result = VoiceExpenseParser.parse('12.50');
    expect(result.title, 'Voice entry');
    expect(result.amount, 12.5);
  });
}
