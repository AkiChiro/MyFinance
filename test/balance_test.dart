import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfinance/data/database.dart';
import 'package:myfinance/models/domain.dart';
import 'package:myfinance/repositories/finance_repository.dart';

Wallet _wallet({int initialBalance = 0}) => Wallet(
      id: 'w1',
      name: 'Cash',
      initialBalance: initialBalance,
      type: WalletKinds.cash,
    );

Txn _spending(int amount,
        {String walletId = 'w1', bool affectsBalance = true}) =>
    Txn(
      id: 'ts$amount',
      type: TxTypes.spending,
      amount: amount,
      walletId: walletId,
      timestamp: DateTime(2024),
      createdAt: DateTime(2024),
      imported: false,
      starred: false,
      source: SourceType.manual,
      affectsBalance: affectsBalance,
    );

Txn _earning(int amount,
        {String walletId = 'w1', bool affectsBalance = true}) =>
    Txn(
      id: 'te$amount',
      type: TxTypes.earning,
      amount: amount,
      walletId: walletId,
      timestamp: DateTime(2024),
      createdAt: DateTime(2024),
      imported: false,
      starred: false,
      source: SourceType.manual,
      affectsBalance: affectsBalance,
    );

Txn _transfer(int amount,
        {String from = 'w1',
        String to = 'w2',
        bool affectsBalance = true,
        SourceType source = SourceType.manual}) =>
    Txn(
      id: 'tt$amount',
      type: TxTypes.transfer,
      amount: amount,
      walletId: from,
      walletToId: to,
      timestamp: DateTime(2024),
      createdAt: DateTime(2024),
      imported: false,
      starred: false,
      source: source,
      affectsBalance: affectsBalance,
    );

void main() {
  late AppDatabase db;
  late FinanceRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FinanceRepository(db);
  });

  tearDown(() => db.close());

  group('balanceOf', () {
    test('returns initialBalance when no transactions', () {
      expect(repo.balanceOf(_wallet(initialBalance: 500000), []), 500000);
    });

    test('spending reduces balance', () {
      final txns = [_spending(100000)];
      expect(repo.balanceOf(_wallet(initialBalance: 500000), txns), 400000);
    });

    test('earning increases balance', () {
      final txns = [_earning(200000)];
      expect(repo.balanceOf(_wallet(initialBalance: 100000), txns), 300000);
    });

    test('transfer deducts from source wallet', () {
      final txns = [_transfer(50000, from: 'w1', to: 'w2')];
      expect(repo.balanceOf(_wallet(initialBalance: 200000), txns), 150000);
    });

    test('transfer adds to destination wallet', () {
      const dest = Wallet(
          id: 'w2', name: 'Bank', initialBalance: 0, type: WalletKinds.bank);
      final txns = [_transfer(50000, from: 'w1', to: 'w2')];
      expect(repo.balanceOf(dest, txns), 50000);
    });

    test('affectsBalance=false transactions are excluded from balance', () {
      final txns = [
        _spending(100000), // native manual — counted
        _transfer(200000, affectsBalance: false), // archive-only — skipped
      ];
      expect(repo.balanceOf(_wallet(initialBalance: 500000), txns), 400000);
    });

    test('bankNotification row with affectsBalance=true counts toward balance', () {
      final txns = [
        _earning(150000,
            affectsBalance: true), // bank-source but affects balance
      ];
      // Even though source is manual here, the flag is what matters
      expect(repo.balanceOf(_wallet(initialBalance: 0), txns), 150000);
    });

    test('csvImport row with affectsBalance=false is excluded from balance', () {
      final txns = [
        _spending(100000, affectsBalance: false),
        _earning(200000, affectsBalance: false),
      ];
      // All context-only — balance unchanged
      expect(repo.balanceOf(_wallet(initialBalance: 300000), txns), 300000);
    });

    test('transactions from other wallets do not affect balance', () {
      final txns = [_spending(100000, walletId: 'w99')];
      expect(repo.balanceOf(_wallet(initialBalance: 300000), txns), 300000);
    });
  });
}
