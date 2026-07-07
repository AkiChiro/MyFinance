import 'package:flutter_test/flutter_test.dart';
import 'package:myfinance/models/domain.dart';
import 'package:myfinance/services/category_suggester.dart';

void main() {
  group('CategorySuggester.fromRules', () {
    test('returns fallback category when no rules match', () {
      final s = CategorySuggester.fromRules([]);
      expect(s.suggest('random text', TxTypes.spending),
          Categories.fallbackFor(TxTypes.spending));
    });

    test('matches a keyword and returns its category', () {
      final s = CategorySuggester.fromRules([
        {'keyword': 'trà sữa', 'category': 'food', 'weight': 5},
      ]);
      expect(s.suggest('trà sữa hôm nay', TxTypes.spending), 'food');
    });

    test('is case-insensitive', () {
      final s = CategorySuggester.fromRules([
        {'keyword': 'grab', 'category': 'necessities', 'weight': 5},
      ]);
      expect(s.suggest('GRAB food', TxTypes.spending), 'necessities');
    });

    test('picks highest-weight category when multiple rules match', () {
      final s = CategorySuggester.fromRules([
        {'keyword': 'phim', 'category': 'hobbies', 'weight': 3},
        {'keyword': 'rạp', 'category': 'hobbies', 'weight': 3},
        {'keyword': 'ăn', 'category': 'food', 'weight': 8},
      ]);
      // "ăn phim" matches food(8) and hobbies(3) → food wins
      expect(s.suggest('ăn phim', TxTypes.spending), 'food');
    });

    test('ignores categories not valid for the given txType', () {
      final s = CategorySuggester.fromRules([
        // 'food' is a spending category; when txType=earning it should be filtered
        {'keyword': 'food', 'category': 'food', 'weight': 10},
      ]);
      expect(s.suggest('food', TxTypes.earning),
          Categories.fallbackFor(TxTypes.earning));
    });

    test('accumulated weight from multiple keyword hits', () {
      final s = CategorySuggester.fromRules([
        {'keyword': 'cà phê', 'category': 'food', 'weight': 3},
        {'keyword': 'sáng', 'category': 'food', 'weight': 3},
        {'keyword': 'taxi', 'category': 'necessities', 'weight': 10},
      ]);
      // "cà phê buổi sáng" → food(6), no taxi hit → food wins
      expect(s.suggest('cà phê buổi sáng', TxTypes.spending), 'food');
    });
  });
}
