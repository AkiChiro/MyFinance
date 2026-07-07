import 'package:flutter_test/flutter_test.dart';
import 'package:myfinance/data/database.dart';
import 'package:myfinance/models/domain.dart';
import 'package:myfinance/repositories/finance_repository.dart';

Txn _txn({
  String type = TxTypes.spending,
  int amount = 100000,
  String? category = 'food',
  bool imported = false,
  String? walletToId,
}) =>
    Txn(
      id: 't1',
      type: type,
      amount: amount,
      walletId: 'w1',
      walletToId: walletToId,
      category: category,
      timestamp: DateTime(2024, 1, 1),
      createdAt: DateTime(2024, 1, 1),
      imported: imported,
      starred: false,
      source: SourceType.manual,
      affectsBalance: true,
    );

void main() {
  const thresholds = {'food': 50000, 'hobbies': 500000};

  group('isAutoStarred', () {
    test('returns false when autostar is disabled', () {
      final t = _txn(amount: 999999);
      expect(isAutoStarred(t, thresholds, enabled: false), isFalse);
    });

    test('returns true when spending exceeds category threshold', () {
      final t = _txn(amount: 100000, category: 'food');
      expect(isAutoStarred(t, thresholds, enabled: true), isTrue);
    });

    test('returns false when spending is at or below threshold', () {
      final t = _txn(amount: 50000, category: 'food');
      expect(isAutoStarred(t, thresholds, enabled: true), isFalse);
    });

    test('returns false for earning type', () {
      final t = _txn(type: TxTypes.earning, amount: 999999, category: 'food');
      expect(isAutoStarred(t, thresholds, enabled: true), isFalse);
    });

    test('returns false for transfer type', () {
      final t = _txn(
          type: TxTypes.transfer,
          amount: 999999,
          walletToId: 'w2',
          category: null);
      expect(isAutoStarred(t, thresholds, enabled: true), isFalse);
    });

    test('returns false for imported transactions', () {
      final t = _txn(amount: 999999, imported: true);
      expect(isAutoStarred(t, thresholds, enabled: true), isFalse);
    });

    test('returns false when category has no threshold', () {
      final t = _txn(amount: 999999, category: 'others');
      expect(isAutoStarred(t, thresholds, enabled: true), isFalse);
    });
  });
}
