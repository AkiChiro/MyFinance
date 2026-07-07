import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfinance/data/database.dart';
import 'package:myfinance/repositories/finance_repository.dart';

AppDatabase _openDb() => AppDatabase.forTesting(NativeDatabase.memory());

void main() {
  late AppDatabase db;
  late FinanceRepository repo;

  setUp(() async {
    db = _openDb();
    repo = FinanceRepository(db);
    // Seed two wallets
    await repo.addWallet(name: 'Main', initialBalance: 300000);
    await repo.addWallet(name: 'Savings', initialBalance: 0);
  });

  tearDown(() => db.close());

  Future<String> walletId(String name) async {
    final wallets = await db.allWallets();
    return wallets.firstWhere((w) => w.name == name).id;
  }

  group('addSpending overspend', () {
    test('succeeds when amount <= balance', () async {
      final id = await walletId('Main');
      await expectLater(
        repo.addSpending(amount: 300000, walletId: id, category: 'food'),
        completes,
      );
    });

    test('throws OverspendException when amount > balance', () async {
      final id = await walletId('Main');
      await expectLater(
        repo.addSpending(amount: 300001, walletId: id, category: 'food'),
        throwsA(isA<OverspendException>()),
      );
    });

    test('does not insert transaction on overspend (atomic rollback)', () async {
      final id = await walletId('Main');
      try {
        await repo.addSpending(amount: 999999, walletId: id, category: 'food');
      } on OverspendException {
        // expected
      }
      final txns = await db.allTxns();
      expect(txns, isEmpty);
    });
  });

  group('addTransfer overspend', () {
    test('throws OverspendException when source lacks funds', () async {
      final from = await walletId('Main');
      final to = await walletId('Savings');
      await expectLater(
        repo.addTransfer(amount: 300001, fromWalletId: from, toWalletId: to),
        throwsA(isA<OverspendException>()),
      );
    });

    test('succeeds when source has enough funds', () async {
      final from = await walletId('Main');
      final to = await walletId('Savings');
      await expectLater(
        repo.addTransfer(amount: 100000, fromWalletId: from, toWalletId: to),
        completes,
      );
    });
  });
}
