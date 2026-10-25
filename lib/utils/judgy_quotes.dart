import 'dart:math';

class JudgyQuotes {
  static final Random _random = Random();

  static const Map<String, List<String>> _quotes = {
    'Coffee': [
      "Another iced coffee? In this economy?",
      "You're single-handedly funding the barista's retirement.",
      "Just drink water, it's free.",
    ],
    'Food': [
      "Cooking at home is a thing, you know.",
      "Your fridge is crying right now.",
      "Again? Really?",
    ],
    'Shopping': [
      "Do you really need this, or are you just sad?",
      "Add to cart? More like add to debt.",
      "Your wallet is begging for mercy.",
    ],
    'Subscriptions': [
      "You don't even use this.",
      "Ah yes, paying monthly to ignore it daily.",
    ],
    'Other': [
      "Interesting financial decision.",
      "I'm not mad, I'm just disappointed.",
      "Is this why you're broke?",
    ],
  };

  static String getQuote(String category, double amount) {
    if (amount > 100) {
      return "Wow. Big spender. Must be nice.";
    }

    final categoryQuotes = _quotes[category] ?? _quotes['Other']!;
    return categoryQuotes[_random.nextInt(categoryQuotes.length)];
  }
}
