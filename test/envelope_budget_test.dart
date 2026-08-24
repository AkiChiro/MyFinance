import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfinance/data/database.dart';
import 'package:myfinance/models/domain.dart';
import 'package:myfinance/repositories/finance_repository.dart';

AppDatabase _openDb() => AppDatabase.forTesting(NativeDatabase.memory());

// ---------------------------------------------------------------------------
// Helpers — direct DB inserts bypass the repository so history rows and txn
// timestamps can be pinned to exact, deterministic values (mirrors
// sql_analytics_test.dart's `_insert` "bypasses overspend check for test
// flexibility" precedent).
// ---------------------------------------------------------------------------

int _seq = 0;

/// AppDatabase.forTesting still runs onCreate for a fresh in-memory DB, which
/// seeds necessities/food/hobbies/others at 50/15/20/15 (effectiveFrom: 0) —
/// exactly the feature's own worked example. Tests below lean on this seed
/// rather than re-inserting it.
DateTime _ts(int unixSeconds) =>
    DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);

Future<void> _insertTxn(
  AppDatabase db, {
  required String type,
  required int amount,
  required String walletId,
  String? category,
  bool affectsBalance = true,
  required int timestamp,
}) async {
  final id = 'envtx${++_seq}';
  await db.into(db.txns).insert(TxnsCompanion.insert(
        id: id,
        type: type,
        amount: amount,
        walletId: walletId,
        category: Value(category),
        timestamp: _ts(timestamp),
        createdAt: _ts(timestamp),
        source: const Value(SourceType.manual),
        affectsBalance: Value(affectsBalance),
      ));
}

Future<void> _insertPct(
  AppDatabase db, {
  required String categoryId,
  required int percent,
  required int effectiveFrom,
}) async {
  await db.into(db.categoryBudgetHistory).insert(
        CategoryBudgetHistoryCompanion.insert(
          id: 'envpct${++_seq}',
          categoryId: categoryId,
          percent: percent,
          effectiveFrom: effectiveFrom,
        ),
      );
}

void main() {
  late AppDatabase db;
  late FinanceRepository repo;
  late String wid;

  setUp(() async {
    _seq = 0;
    db = _openDb();
    repo = FinanceRepository(db);
    wid = await repo.addWallet(name: 'Main', initialBalance: 5000000);
  });

  tearDown(() => db.close());

  group('envelope balances', () {
    test('worked example: 1,000,000 @ 50/15/20/15 → 500k/150k/200k/150k',
        () async {
      await _insertTxn(db,
          type: TxTypes.earning, amount: 1000000, walletId: wid, timestamp: 100);

      final balances = await db.watchEnvelopeBalances().first;

      expect(balances['necessities']?.balance, 500000);
      expect(balances['food']?.balance, 150000);
      expect(balances['hobbies']?.balance, 200000);
      expect(balances['others']?.balance, 150000);
    });

    test('percent change is not retroactive — past allocations frozen',
        () async {
      // Seed row: necessities=50%, effectiveFrom=0.
      await _insertTxn(db,
          type: TxTypes.earning, amount: 1000000, walletId: wid, timestamp: 1000);
      // Change necessities to 40%, effective from t=5000.
      await _insertPct(db, categoryId: 'necessities', percent: 40, effectiveFrom: 5000);
      await _insertTxn(db,
          type: TxTypes.earning, amount: 1000000, walletId: wid, timestamp: 6000);

      final balances = await db.watchEnvelopeBalances().first;

      // 500k (old 50%) + 400k (new 40%) = 900k. A retroactive design would
      // read 400k + 400k = 800k instead — this is the decisive assertion.
      expect(balances['necessities']?.balance, 900000);
    });

    test('spending drives an envelope negative and the txn still persists',
        () async {
      await _insertTxn(db,
          type: TxTypes.earning, amount: 100000, walletId: wid, timestamp: 100);
      // necessities envelope = 50,000. Spend past it — wallet has plenty of
      // real balance (5,000,000), so only the envelope goes negative.
      await repo.addSpending(
          amount: 200000, walletId: wid, category: 'necessities');

      final balances = await db.watchEnvelopeBalances().first;
      expect(balances['necessities']?.balance, 50000 - 200000);
      final txns = await db.allTxns();
      expect(txns.where((t) => t.category == 'necessities'), isNotEmpty);
    });

    test('null-category spending falls into the "others" envelope', () async {
      await _insertTxn(db,
          type: TxTypes.earning, amount: 100000, walletId: wid, timestamp: 100);
      await _insertTxn(db,
          type: TxTypes.spending,
          amount: 5000,
          walletId: wid,
          category: null,
          timestamp: 200);

      final balances = await db.watchEnvelopeBalances().first;
      // others envelope = 15,000 (15% of 100k) - 5,000 spent.
      expect(balances['others']?.balance, 15000 - 5000);
    });

    test('affects_balance=0 rows are excluded from both sides', () async {
      await _insertTxn(db,
          type: TxTypes.earning,
          amount: 1000000,
          walletId: wid,
          timestamp: 100,
          affectsBalance: false);
      await _insertTxn(db,
          type: TxTypes.spending,
          amount: 999,
          walletId: wid,
          category: 'necessities',
          timestamp: 200,
          affectsBalance: false);

      final balances = await db.watchEnvelopeBalances().first;
      expect(balances['necessities']?.balance, 0);
    });

    test('transfers never participate', () async {
      final wid2 = await repo.addWallet(name: 'Other', initialBalance: 0);
      await _insertTxn(db,
          type: TxTypes.earning, amount: 100000, walletId: wid, timestamp: 100);
      await db.into(db.txns).insert(TxnsCompanion.insert(
            id: 'envtransfer',
            type: TxTypes.transfer,
            amount: 5000,
            walletId: wid,
            walletToId: Value(wid2),
            timestamp: _ts(200),
            createdAt: _ts(200),
            source: const Value(SourceType.manual),
            affectsBalance: const Value(true),
          ));

      final balances = await db.watchEnvelopeBalances().first;
      // Unaffected by the transfer — still exactly 50% of the earning.
      expect(balances['necessities']?.balance, 50000);
    });

    test('earning before any percent was ever configured contributes \$0',
        () async {
      final freshCatId =
          await repo.addCategory(label: 'Fresh', kind: TxTypes.spending);
      await _insertTxn(db,
          type: TxTypes.earning, amount: 1000000, walletId: wid, timestamp: 100);

      final balances = await db.watchEnvelopeBalances().first;
      expect(balances[freshCatId]?.balance, 0);
    });

    test('archived category is absent from the map', () async {
      await _insertTxn(db,
          type: TxTypes.earning, amount: 1000000, walletId: wid, timestamp: 100);
      await repo.archiveCategory('hobbies');

      final balances = await db.watchEnvelopeBalances().first;
      expect(balances.containsKey('hobbies'), isFalse);
    });

    test('percentages summing to <100% leave the remainder untracked',
        () async {
      // Lower "others" from 15% to 5% from t=10000 onward — active sum
      // becomes 50+15+20+5=90%.
      await _insertPct(db, categoryId: 'others', percent: 5, effectiveFrom: 10000);
      await _insertTxn(db,
          type: TxTypes.earning, amount: 1000000, walletId: wid, timestamp: 20000);

      final balances = await db.watchEnvelopeBalances().first;
      final tracked = balances.values.fold<int>(0, (a, b) => a + b.balance);
      // 500k + 150k + 200k + 50k = 900k of the 1,000,000 earning — the
      // remaining 100k (10%) is real money but isn't in any envelope.
      expect(tracked, 900000);
    });

    test('updateTxn/deleteTxn on an earning changes the next read with zero '
        'envelope-specific code in either method', () async {
      await repo.addEarning(amount: 1000000, walletId: wid, category: 'provided');
      final earningTxn =
          (await db.allTxns()).firstWhere((t) => t.type == TxTypes.earning);

      var balances = await db.watchEnvelopeBalances().first;
      expect(balances['necessities']?.balance, 500000);

      await repo.updateTxn(earningTxn.copyWith(amount: 2000000));
      balances = await db.watchEnvelopeBalances().first;
      expect(balances['necessities']?.balance, 1000000);

      await repo.deleteTxn(earningTxn.id);
      balances = await db.watchEnvelopeBalances().first;
      expect(balances['necessities']?.balance, 0);
    });

    group('resetEnvelope', () {
      test('reset zeroes both allocated and spent when nothing follows',
          () async {
        await _insertTxn(db,
            type: TxTypes.earning, amount: 1000000, walletId: wid, timestamp: 100);
        await _insertTxn(db,
            type: TxTypes.spending,
            amount: 20000,
            walletId: wid,
            category: 'necessities',
            timestamp: 200);

        await repo.resetEnvelope('necessities', at: _ts(1000));

        final balances = await db.watchEnvelopeBalances().first;
        expect(balances['necessities']?.allocated, 0);
        expect(balances['necessities']?.spent, 0);
      });

      test('earning before the cutoff excluded, one after still counted',
          () async {
        await _insertTxn(db,
            type: TxTypes.earning, amount: 1000000, walletId: wid, timestamp: 100);
        await repo.resetEnvelope('necessities', at: _ts(1000));
        await _insertTxn(db,
            type: TxTypes.earning, amount: 1000000, walletId: wid, timestamp: 2000);

        final balances = await db.watchEnvelopeBalances().first;
        // Only the post-cutoff earning counts: 50% of 1,000,000.
        expect(balances['necessities']?.allocated, 500000);
      });

      test('spending before the cutoff excluded, one after still counted',
          () async {
        await _insertTxn(db,
            type: TxTypes.spending,
            amount: 10000,
            walletId: wid,
            category: 'necessities',
            timestamp: 100);
        await repo.resetEnvelope('necessities', at: _ts(1000));
        await _insertTxn(db,
            type: TxTypes.spending,
            amount: 30000,
            walletId: wid,
            category: 'necessities',
            timestamp: 2000);

        final balances = await db.watchEnvelopeBalances().first;
        expect(balances['necessities']?.spent, 30000);
      });

      test("resetting one category doesn't affect another", () async {
        await _insertTxn(db,
            type: TxTypes.earning, amount: 1000000, walletId: wid, timestamp: 100);

        await repo.resetEnvelope('necessities', at: _ts(1000));

        final balances = await db.watchEnvelopeBalances().first;
        expect(balances['necessities']?.allocated, 0);
        // food/hobbies/others are untouched by necessities' own reset.
        expect(balances['food']?.balance, 150000);
        expect(balances['hobbies']?.balance, 200000);
        expect(balances['others']?.balance, 150000);
      });

      test('a txn exactly at the cutoff still counts (>=, not >)', () async {
        await repo.resetEnvelope('necessities', at: _ts(1000));
        await _insertTxn(db,
            type: TxTypes.earning, amount: 1000000, walletId: wid, timestamp: 1000);

        final balances = await db.watchEnvelopeBalances().first;
        expect(balances['necessities']?.allocated, 500000);
      });

      test('archiving and unarchiving does not clear the cutoff', () async {
        await _insertTxn(db,
            type: TxTypes.earning, amount: 1000000, walletId: wid, timestamp: 100);
        await repo.resetEnvelope('necessities', at: _ts(1000));

        await repo.archiveCategory('necessities');
        await repo.unarchiveCategory('necessities');

        final balances = await db.watchEnvelopeBalances().first;
        // Pre-cutoff earning still excluded after the archive round-trip.
        expect(balances['necessities']?.allocated, 0);
      });
    });

    group('reactivity', () {
      // Plain .listen() rather than StreamIterator: StreamIterator pauses
      // its underlying subscription between moveNext() calls, and for an
      // async* generator a paused subscription suspends the generator body
      // too — it never even reaches the inner `await for (tableUpdates(...))`
      // before the test's mutation fires, so the notification is missed and
      // the second moveNext() hangs forever. A live StreamBuilder in the
      // running app never pauses like this, so this is purely a test-
      // consumption-pattern issue, not a bug in watchEnvelopeBalances itself.
      Future<List<Map<String, EnvelopeStatus>>> collectTwo(
          Stream<Map<String, EnvelopeStatus>> stream,
          Future<void> Function() mutate) async {
        final events = <Map<String, EnvelopeStatus>>[];
        final second = Completer<void>();
        final sub = stream.listen((v) {
          events.add(v);
          if (events.length == 2 && !second.isCompleted) second.complete();
        });
        await Future.delayed(Duration.zero); // let the initial event land
        await mutate();
        await second.future.timeout(const Duration(seconds: 2));
        await sub.cancel();
        return events;
      }

      test('re-emits on a txns insert', () async {
        final events = await collectTwo(
          db.watchEnvelopeBalances(),
          () => _insertTxn(db,
              type: TxTypes.earning, amount: 100000, walletId: wid, timestamp: 100),
        );
        expect(events.last['necessities']?.balance, 50000);
      });

      test('re-emits on setCategoryBudgetPercent', () async {
        // 45+15+20+15=95, stays within budget.
        await collectTwo(db.watchEnvelopeBalances(),
            () => repo.setCategoryBudgetPercent('necessities', 45));
      });

      test('re-emits on archiveCategory', () async {
        final events = await collectTwo(
            db.watchEnvelopeBalances(), () => repo.archiveCategory('hobbies'));
        expect(events.last.containsKey('hobbies'), isFalse);
      });

      test('re-emits on resetEnvelope', () async {
        await _insertTxn(db,
            type: TxTypes.earning, amount: 1000000, walletId: wid, timestamp: 100);
        final events = await collectTwo(
            db.watchEnvelopeBalances(), () => repo.resetEnvelope('necessities'));
        expect(events.last['necessities']?.allocated, 0);
      });
    });
  });

  group('setCategoryBudgetPercent validation guard', () {
    test('sums to exactly 100% succeeds', () async {
      await expectLater(
        repo.setCategoryBudgetPercent('others', 15), // unchanged, sum stays 100
        completes,
      );
    });

    test('pushing the sum to 101% throws BudgetPercentExceededException',
        () async {
      await expectLater(
        repo.setCategoryBudgetPercent('others', 16),
        throwsA(isA<BudgetPercentExceededException>()),
      );
    });

    test('a caught exception leaves the percent unchanged (atomicity)',
        () async {
      try {
        await repo.setCategoryBudgetPercent('others', 16);
      } on BudgetPercentExceededException {
        // expected
      }
      final percents = await db.categoryBudgetPercents();
      expect(percents['others'], 15);
    });

    test("replacing a category's own existing percent doesn't double-count it",
        () async {
      // 45+15+20+15=95 — only valid if necessities' OLD 50% is excluded from
      // the sum check, not added on top of the new 45%.
      await expectLater(
        repo.setCategoryBudgetPercent('necessities', 45),
        completes,
      );
    });

    test("an archived category's percent doesn't count toward the active sum",
        () async {
      await repo.archiveCategory('hobbies'); // frees its 20%
      // Active sum without hobbies: 50+35+15=100 — would be 120 (over) if
      // the archived category's frozen 20% still counted.
      await expectLater(
        repo.setCategoryBudgetPercent('food', 35),
        completes,
      );
    });
  });
}
