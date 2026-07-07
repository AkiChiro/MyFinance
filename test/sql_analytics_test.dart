import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfinance/data/database.dart';
import 'package:myfinance/models/domain.dart';
import 'package:myfinance/repositories/finance_repository.dart';

AppDatabase _openDb() => AppDatabase.forTesting(NativeDatabase.memory());

// ---------------------------------------------------------------------------
// Oracle: exact replica of the Dart fold removed from analytics_page.dart.
// Used as ground truth in equivalence assertions.
// ---------------------------------------------------------------------------

Map<String, int> _dartCategoryTotals(
    List<Txn> txns, String type, DateTime month) {
  final fallback = type == TxTypes.spending ? 'others' : 'others_earn';
  final result = <String, int>{};
  for (final t in txns) {
    if (!t.affectsBalance) continue;
    if (t.type == TxTypes.transfer) continue;
    if (t.type != type) continue;
    if (t.timestamp.year != month.year || t.timestamp.month != month.month) {
      continue;
    }
    final cat = t.category ?? fallback;
    result[cat] = (result[cat] ?? 0) + t.amount;
  }
  return result;
}

int _dartYearTotal(List<Txn> txns, String type, int year) {
  var total = 0;
  for (final t in txns) {
    if (!t.affectsBalance) continue;
    if (t.type == TxTypes.transfer) continue;
    if (t.type != type) continue;
    if (t.timestamp.year != year) continue;
    total += t.amount;
  }
  return total;
}

// ---------------------------------------------------------------------------
// Insert helper (bypasses overspend check for test flexibility)
// ---------------------------------------------------------------------------

int _txnSeq = 0;

Future<void> _insert(
  AppDatabase db, {
  required String type,
  required int amount,
  required String walletId,
  String? category,
  bool affectsBalance = true,
  required DateTime timestamp,
}) async {
  final id = 'anx${++_txnSeq}';
  await db.into(db.txns).insert(TxnsCompanion.insert(
        id: id,
        type: type,
        amount: amount,
        walletId: walletId,
        category: Value(category),
        timestamp: timestamp,
        createdAt: timestamp,
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
  late String wid;

  setUp(() async {
    _txnSeq = 0;
    db = _openDb();
    repo = FinanceRepository(db);
    await repo.addWallet(name: 'Test', initialBalance: 0);
    wid = (await db.allWallets()).first.id;
  });

  tearDown(() => db.close());

  group('empty database', () {
    test('all period totals are zero', () async {
      final b = await db.watchAnalyticsBundle(DateTime(2024, 6)).first;
      expect(b.currSpending, 0);
      expect(b.currEarning, 0);
      expect(b.prevSpending, 0);
      expect(b.prevEarning, 0);
      expect(b.yearSpending, 0);
      expect(b.yearEarning, 0);
      expect(b.spendByCat, isEmpty);
      expect(b.earnByCat, isEmpty);
    });
  });

  group('month boundary rows', () {
    // These tests prove the half-open local-time range [start, end) matches
    // the Dart fold's t.timestamp.year/month comparison exactly.

    test('23:59:59.999 on last day of month is IN that month', () async {
      final lastMomentJan = DateTime(2024, 1, 31, 23, 59, 59, 999);
      await _insert(db,
          type: TxTypes.spending,
          amount: 100000,
          walletId: wid,
          category: 'food',
          timestamp: lastMomentJan);

      final janBundle =
          await db.watchAnalyticsBundle(DateTime(2024, 1)).first;
      final febBundle =
          await db.watchAnalyticsBundle(DateTime(2024, 2)).first;

      expect(janBundle.currSpending, 100000,
          reason: '23:59:59.999 Jan 31 must be in January');
      expect(febBundle.currSpending, 0,
          reason: '23:59:59.999 Jan 31 must NOT be in February');
    });

    test('00:00:00.000 on first day of next month is in NEXT month', () async {
      final firstMomentFeb = DateTime(2024, 2, 1, 0, 0, 0, 0);
      await _insert(db,
          type: TxTypes.spending,
          amount: 200000,
          walletId: wid,
          category: 'food',
          timestamp: firstMomentFeb);

      final janBundle =
          await db.watchAnalyticsBundle(DateTime(2024, 1)).first;
      final febBundle =
          await db.watchAnalyticsBundle(DateTime(2024, 2)).first;

      expect(janBundle.currSpending, 0,
          reason: '00:00 Feb 1 must NOT be in January');
      expect(febBundle.currSpending, 200000,
          reason: '00:00 Feb 1 must be in February');
    });

    test('year boundary: Dec 31 23:59:59.999 is in the old year', () async {
      final lastMomentDec = DateTime(2023, 12, 31, 23, 59, 59, 999);
      await _insert(db,
          type: TxTypes.earning,
          amount: 500000,
          walletId: wid,
          category: 'provided',
          timestamp: lastMomentDec);

      final dec2023 =
          await db.watchAnalyticsBundle(DateTime(2023, 12)).first;
      final jan2024 =
          await db.watchAnalyticsBundle(DateTime(2024, 1)).first;

      expect(dec2023.yearEarning, 500000,
          reason: 'Dec 31 23:59 must be in yearEarning for 2023');
      expect(jan2024.yearEarning, 0,
          reason: 'Dec 31 23:59 must NOT appear in 2024 year total');
    });
  });

  group('SQL matches Dart oracle', () {
    test('category totals with NULL category → fallback', () async {
      final month = DateTime(2024, 3);
      // explicit category
      await _insert(db, type: TxTypes.spending, amount: 100000, walletId: wid,
          category: 'food', timestamp: month);
      // null category → should fold into 'others'
      await _insert(db, type: TxTypes.spending, amount: 50000, walletId: wid,
          category: null, timestamp: month);
      // earning with null category → 'others_earn'
      await _insert(db, type: TxTypes.earning, amount: 200000, walletId: wid,
          category: null, timestamp: month);

      final bundle = await db.watchAnalyticsBundle(month).first;
      final allTxns = await db.allTxns();

      final dartSpend = _dartCategoryTotals(allTxns, TxTypes.spending, month);
      final dartEarn  = _dartCategoryTotals(allTxns, TxTypes.earning,  month);

      expect(bundle.spendByCat, dartSpend,
          reason: 'spending category map SQL == Dart oracle');
      expect(bundle.earnByCat, dartEarn,
          reason: 'earning category map SQL == Dart oracle');
      // Verify the fallback key is present
      expect(bundle.spendByCat['others'], 50000);
      expect(bundle.earnByCat['others_earn'], 200000);
    });

    test('transfers are excluded from analytics', () async {
      final month = DateTime(2024, 4);
      await _insert(db, type: TxTypes.spending, amount: 100000, walletId: wid,
          category: 'food', timestamp: month);

      // add a second wallet and a transfer
      await repo.addWallet(name: 'W2', initialBalance: 0);
      final w2 = (await db.allWallets()).firstWhere((w) => w.name == 'W2');
      await db.into(db.txns).insert(TxnsCompanion.insert(
            id: 'tr_test',
            type: TxTypes.transfer,
            amount: 99999,
            walletId: wid,
            walletToId: Value(w2.id),
            timestamp: month,
            createdAt: month,
            source: const Value(SourceType.manual),
            affectsBalance: const Value(true),
          ));

      final bundle = await db.watchAnalyticsBundle(month).first;
      expect(bundle.currSpending, 100000,
          reason: 'transfer must not appear in currSpending');
    });

    test('affectsBalance=false excluded from analytics', () async {
      final month = DateTime(2024, 5);
      await _insert(db, type: TxTypes.spending, amount: 100000, walletId: wid,
          category: 'food', timestamp: month);
      await _insert(db, type: TxTypes.spending, amount: 999000, walletId: wid,
          category: 'food', timestamp: month, affectsBalance: false);

      final bundle = await db.watchAnalyticsBundle(month).first;
      expect(bundle.currSpending, 100000,
          reason: 'context-only row must not appear in currSpending');
    });

    test('prevMonth totals match Dart oracle', () async {
      final curr = DateTime(2024, 6);
      final prev = DateTime(2024, 5);
      await _insert(db, type: TxTypes.spending, amount: 300000, walletId: wid,
          category: 'necessities', timestamp: prev);
      await _insert(db, type: TxTypes.earning, amount: 500000, walletId: wid,
          category: 'provided', timestamp: prev);
      await _insert(db, type: TxTypes.spending, amount: 100000, walletId: wid,
          category: 'food', timestamp: curr);

      final bundle = await db.watchAnalyticsBundle(curr).first;
      final allTxns = await db.allTxns();

      expect(bundle.prevSpending,
          _dartCategoryTotals(allTxns, TxTypes.spending, prev).values.fold(0, (a, b) => a + b));
      expect(bundle.prevEarning,
          _dartCategoryTotals(allTxns, TxTypes.earning, prev).values.fold(0, (a, b) => a + b));
    });

    test('yearTotal SQL == sum of monthly SQL totals', () async {
      // Seed one spending per month for all 12 months of 2024
      for (var m = 1; m <= 12; m++) {
        await _insert(db,
            type: TxTypes.spending,
            amount: m * 10000,
            walletId: wid,
            category: 'food',
            timestamp: DateTime(2024, m, 15));
      }

      // Sum up SQL currSpending for each month
      var monthlySum = 0;
      for (var m = 1; m <= 12; m++) {
        final b = await db.watchAnalyticsBundle(DateTime(2024, m)).first;
        monthlySum += b.currSpending;
      }

      // Compare against yearSpending from any 2024 month bundle
      final anyBundle =
          await db.watchAnalyticsBundle(DateTime(2024, 6)).first;

      expect(anyBundle.yearSpending, monthlySum,
          reason: 'yearSpending == sum of monthly currSpending totals');
    });

    test('yearTotal SQL == Dart oracle yearTotal', () async {
      for (var m = 1; m <= 6; m++) {
        await _insert(db,
            type: TxTypes.spending,
            amount: m * 50000,
            walletId: wid,
            category: m.isOdd ? 'food' : 'others',
            timestamp: DateTime(2024, m, 10));
        await _insert(db,
            type: TxTypes.earning,
            amount: m * 100000,
            walletId: wid,
            category: 'provided',
            timestamp: DateTime(2024, m, 20));
      }

      final allTxns = await db.allTxns();
      final bundle = await db.watchAnalyticsBundle(DateTime(2024, 6)).first;

      expect(bundle.yearSpending, _dartYearTotal(allTxns, TxTypes.spending, 2024),
          reason: 'yearSpending SQL == Dart oracle');
      expect(bundle.yearEarning, _dartYearTotal(allTxns, TxTypes.earning, 2024),
          reason: 'yearEarning SQL == Dart oracle');
    });

    test('January prevMonth looks into previous year', () async {
      // prevMonth for January 2024 is December 2023
      final dec2023 = DateTime(2023, 12, 15);
      final jan2024 = DateTime(2024, 1, 15);
      await _insert(db, type: TxTypes.spending, amount: 400000, walletId: wid,
          category: 'necessities', timestamp: dec2023);
      await _insert(db, type: TxTypes.spending, amount: 100000, walletId: wid,
          category: 'food', timestamp: jan2024);

      final bundle =
          await db.watchAnalyticsBundle(DateTime(2024, 1)).first;
      final allTxns = await db.allTxns();

      expect(bundle.prevSpending,
          _dartCategoryTotals(allTxns, TxTypes.spending, DateTime(2023, 12))
              .values
              .fold(0, (a, b) => a + b),
          reason: 'Jan prevSpending should come from Dec of previous year');
      expect(bundle.currSpending, 100000);
    });
  });
}
