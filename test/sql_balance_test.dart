import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfinance/data/database.dart';
import 'package:myfinance/models/domain.dart';
import 'package:myfinance/repositories/finance_repository.dart';

AppDatabase _openDb() => AppDatabase.forTesting(NativeDatabase.memory());

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<Wallet> _addWallet(AppDatabase db,
    {String name = 'W', int initialBalance = 0}) async {
  final repo = FinanceRepository(db);
  await repo.addWallet(name: name, initialBalance: initialBalance);
  final wallets = await db.allWallets();
  return wallets.firstWhere((w) => w.name == name);
}

Future<void> _insertTxn(
  AppDatabase db, {
  required String id,
  required String type,
  required int amount,
  required String walletId,
  String? walletToId,
  String? category,
  bool affectsBalance = true,
  DateTime? timestamp,
}) async {
  final now = timestamp ?? DateTime(2024, 6, 1);
  await db.into(db.txns).insert(TxnsCompanion.insert(
        id: id,
        type: type,
        amount: amount,
        walletId: walletId,
        walletToId: Value(walletToId),
        category: Value(category),
        timestamp: now,
        createdAt: now,
        source: const Value(SourceType.manual),
        affectsBalance: Value(affectsBalance),
      ));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late FinanceRepository repo;

  setUp(() {
    db = _openDb();
    repo = FinanceRepository(db);
  });

  tearDown(() => db.close());

  group('sqlBalance — representative cases', () {
    test('empty wallet returns initialBalance', () async {
      final w = await _addWallet(db, initialBalance: 500000);
      expect(await db.sqlBalance(w.id), 500000);
    });

    test('earning adds to balance', () async {
      final w = await _addWallet(db, initialBalance: 0);
      await _insertTxn(db, id: 't1', type: TxTypes.earning, amount: 200000,
          walletId: w.id, category: 'provided');
      expect(await db.sqlBalance(w.id), 200000);
    });

    test('spending reduces balance', () async {
      final w = await _addWallet(db, initialBalance: 300000);
      await _insertTxn(db, id: 't1', type: TxTypes.spending, amount: 100000,
          walletId: w.id, category: 'food');
      expect(await db.sqlBalance(w.id), 200000);
    });

    test('transfer deducts from source wallet', () async {
      final w1 = await _addWallet(db, name: 'W1', initialBalance: 400000);
      final w2 = await _addWallet(db, name: 'W2', initialBalance: 0);
      await _insertTxn(db, id: 't1', type: TxTypes.transfer, amount: 150000,
          walletId: w1.id, walletToId: w2.id);
      expect(await db.sqlBalance(w1.id), 250000);
    });

    test('transfer adds to destination wallet', () async {
      final w1 = await _addWallet(db, name: 'W1', initialBalance: 400000);
      final w2 = await _addWallet(db, name: 'W2', initialBalance: 0);
      await _insertTxn(db, id: 't1', type: TxTypes.transfer, amount: 150000,
          walletId: w1.id, walletToId: w2.id);
      expect(await db.sqlBalance(w2.id), 150000);
    });

    test('self-transfer nets to zero', () async {
      final w = await _addWallet(db, initialBalance: 300000);
      await _insertTxn(db, id: 't1', type: TxTypes.transfer, amount: 100000,
          walletId: w.id, walletToId: w.id);
      expect(await db.sqlBalance(w.id), 300000);
    });

    test('affectsBalance=false excluded from SQL balance', () async {
      final w = await _addWallet(db, initialBalance: 500000);
      await _insertTxn(db, id: 't1', type: TxTypes.spending, amount: 200000,
          walletId: w.id, category: 'food', affectsBalance: false);
      // context-only row must not reduce the balance
      expect(await db.sqlBalance(w.id), 500000);
    });

    test('excludeId variant omits the specified transaction', () async {
      final w = await _addWallet(db, initialBalance: 500000);
      await _insertTxn(db, id: 'keep', type: TxTypes.spending, amount: 100000,
          walletId: w.id, category: 'food');
      await _insertTxn(db, id: 'exclude', type: TxTypes.spending, amount: 50000,
          walletId: w.id, category: 'food');
      // without exclude: 500000 - 100000 - 50000 = 350000
      expect(await db.sqlBalance(w.id), 350000);
      // with exclude='exclude': 500000 - 100000 = 400000
      expect(await db.sqlBalance(w.id, excludeId: 'exclude'), 400000);
    });

    test('transaction on a different wallet does not affect balance', () async {
      final w1 = await _addWallet(db, name: 'W1', initialBalance: 300000);
      final w2 = await _addWallet(db, name: 'W2', initialBalance: 0);
      await _insertTxn(db, id: 't1', type: TxTypes.spending, amount: 100000,
          walletId: w2.id, category: 'food');
      expect(await db.sqlBalance(w1.id), 300000);
    });
  });

  group('watchWalletBalances', () {
    test('emits correct map for all wallets', () async {
      final w1 = await _addWallet(db, name: 'Cash', initialBalance: 500000);
      final w2 = await _addWallet(db, name: 'Bank', initialBalance: 100000);
      await _insertTxn(db, id: 't1', type: TxTypes.earning, amount: 200000,
          walletId: w1.id, category: 'provided');
      await _insertTxn(db, id: 't2', type: TxTypes.transfer, amount: 50000,
          walletId: w1.id, walletToId: w2.id);

      final balances = await db.watchWalletBalances().first;
      // w1: 500000 + 200000 - 50000 = 650000
      // w2: 100000 + 50000 = 150000
      expect(balances[w1.id], 650000);
      expect(balances[w2.id], 150000);
    });
  });

  group('sqlBalance == balanceOf equivalence', () {
    test('representative multi-wallet scenario', () async {
      final w1 = await _addWallet(db, name: 'W1', initialBalance: 1000000);
      final w2 = await _addWallet(db, name: 'W2', initialBalance: 200000);
      final w3 = await _addWallet(db, name: 'W3', initialBalance: 0);

      await _insertTxn(db, id: 'e1', type: TxTypes.earning,  amount: 300000, walletId: w1.id, category: 'provided');
      await _insertTxn(db, id: 's1', type: TxTypes.spending, amount: 100000, walletId: w1.id, category: 'food');
      await _insertTxn(db, id: 'tr1', type: TxTypes.transfer, amount: 500000, walletId: w1.id, walletToId: w2.id);
      await _insertTxn(db, id: 'tr2', type: TxTypes.transfer, amount: 200000, walletId: w2.id, walletToId: w3.id);
      // context-only rows — must not affect balance
      await _insertTxn(db, id: 'cx1', type: TxTypes.spending, amount: 999000, walletId: w1.id, affectsBalance: false);
      await _insertTxn(db, id: 'cx2', type: TxTypes.earning,  amount: 888000, walletId: w3.id, affectsBalance: false);

      final allTxns = await db.allTxns();
      for (final w in [w1, w2, w3]) {
        expect(
          await db.sqlBalance(w.id),
          repo.balanceOf(w, allTxns),
          reason: 'wallet ${w.name} SQL == Dart',
        );
      }
    });

    test('random data: 200 transactions across 3 wallets', () async {
      final rng = Random(42); // seeded for reproducibility

      final w1 = await _addWallet(db, name: 'R1', initialBalance: 5000000);
      final w2 = await _addWallet(db, name: 'R2', initialBalance: 3000000);
      final w3 = await _addWallet(db, name: 'R3', initialBalance: 1000000);
      final walletIds = [w1.id, w2.id, w3.id];

      final types = [TxTypes.earning, TxTypes.spending, TxTypes.transfer];

      for (var i = 0; i < 200; i++) {
        final type = types[rng.nextInt(3)];
        final amount = (rng.nextInt(200) + 1) * 1000; // 1k–200k
        final fromIdx = rng.nextInt(3);
        final toIdx = (fromIdx + 1 + rng.nextInt(2)) % 3; // different wallet
        final affects = rng.nextDouble() > 0.2; // 80% affect balance

        await _insertTxn(
          db,
          id: 'r$i',
          type: type,
          amount: amount,
          walletId: walletIds[fromIdx],
          walletToId: type == TxTypes.transfer ? walletIds[toIdx] : null,
          category: type != TxTypes.transfer ? 'food' : null,
          affectsBalance: affects,
        );
      }

      final allTxns = await db.allTxns();
      for (final w in [w1, w2, w3]) {
        expect(
          await db.sqlBalance(w.id),
          repo.balanceOf(w, allTxns),
          reason: 'random data: wallet ${w.name} SQL == Dart',
        );
      }
    });

    test('excludeId equivalence: SQL matches Dart oracle with one txn excluded',
        () async {
      final w = await _addWallet(db, initialBalance: 1000000);
      for (var i = 0; i < 5; i++) {
        await _insertTxn(db,
            id: 'tx$i',
            type: TxTypes.spending,
            amount: (i + 1) * 50000,
            walletId: w.id,
            category: 'food');
      }
      final allTxns = await db.allTxns();
      const excludeId = 'tx2';

      final dartResult = repo.balanceOf(
          w, allTxns.where((t) => t.id != excludeId).toList());
      final sqlResult = await db.sqlBalance(w.id, excludeId: excludeId);

      expect(sqlResult, dartResult,
          reason: 'excludeId path SQL == Dart oracle');
    });
  });
}
