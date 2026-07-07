import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfinance/data/database.dart';
import 'package:myfinance/models/domain.dart';
import 'package:myfinance/repositories/finance_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppDatabase _openDb() => AppDatabase.forTesting(NativeDatabase.memory());

Future<String> _addWallet(
  FinanceRepository repo, {
  String name = 'W',
  int initialBalance = 0,
  String? packageName,
}) async {
  await repo.addWallet(name: name, initialBalance: initialBalance);
  final wallets = await repo.allWallets();
  final wallet = wallets.firstWhere((w) => w.name == name);
  if (packageName != null) {
    await (repo.db.update(repo.db.wallets)
          ..where((w) => w.id.equals(wallet.id)))
        .write(WalletsCompanion(packageName: Value(packageName)));
  }
  return wallet.id;
}

// ---------------------------------------------------------------------------
// v4 schema SQL — mirrors the schema BEFORE the 4→5 migration.
// Wallets: no package_name column.
// Txns: includes source + affects_balance (added in v3 migration).
// ---------------------------------------------------------------------------

const _kV4Wallets =
    'CREATE TABLE IF NOT EXISTS "wallets" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, '
    '"initial_balance" INTEGER NOT NULL DEFAULT 0, "type" TEXT NOT NULL DEFAULT \'cash\', '
    'PRIMARY KEY ("id"))';

const _kV4Txns =
    'CREATE TABLE IF NOT EXISTS "txns" ("id" TEXT NOT NULL, "type" TEXT NOT NULL, '
    '"amount" INTEGER NOT NULL, "description" TEXT NULL, "wallet_id" TEXT NOT NULL, '
    '"wallet_to_id" TEXT NULL, "category" TEXT NULL, "timestamp" INTEGER NOT NULL, '
    '"created_at" INTEGER NOT NULL, '
    '"imported" INTEGER NOT NULL DEFAULT 0 CHECK ("imported" IN (0, 1)), '
    '"starred" INTEGER NOT NULL DEFAULT 0 CHECK ("starred" IN (0, 1)), '
    '"wallet_from_name" TEXT NULL, "wallet_to_name" TEXT NULL, '
    '"source" TEXT NOT NULL DEFAULT \'manual\', '
    '"affects_balance" INTEGER NOT NULL DEFAULT 1 CHECK ("affects_balance" IN (0, 1)), '
    'PRIMARY KEY ("id"))';

const _kV4AppCategories =
    'CREATE TABLE IF NOT EXISTS "app_categories" ("id" TEXT NOT NULL, '
    '"label" TEXT NOT NULL, "kind" TEXT NOT NULL, '
    '"threshold" INTEGER NOT NULL DEFAULT 0, '
    '"is_default" INTEGER NOT NULL DEFAULT 0 CHECK ("is_default" IN (0, 1)), '
    '"archived" INTEGER NOT NULL DEFAULT 0 CHECK ("archived" IN (0, 1)), '
    '"sort_order" INTEGER NOT NULL DEFAULT 0, PRIMARY KEY ("id"))';

class _V4Db extends GeneratedDatabase {
  _V4Db(super.e);

  @override
  int get schemaVersion => 4;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await customStatement(_kV4Wallets);
          await customStatement(_kV4Txns);
          await customStatement(_kV4AppCategories);
          // v4 partial indexes (Phase 4)
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_txns_affects_wid ON txns(wallet_id) WHERE affects_balance=1',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_txns_affects_wtoid ON txns(wallet_to_id) WHERE affects_balance=1 AND wallet_to_id IS NOT NULL',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_txns_affects_ts ON txns(timestamp) WHERE affects_balance=1',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_txns_affects_type ON txns(type, timestamp) WHERE affects_balance=1',
          );
        },
      );
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

  // ─────────────────────────────────────────────────────────────────────────
  group('insertCapture', () {
    test('stores row with correct fields', () async {
      await _addWallet(repo);
      final capturedAt = DateTime(2024, 6, 15, 10, 0);

      final capture = await repo.insertCapture(
        packageName: 'com.bank.app',
        rawTitle: 'Biến động số dư',
        rawText: 'Tài khoản -500,000 VND',
        capturedAt: capturedAt,
        amount: 500000,
        direction: CaptureDirection.expense,
        parseStatus: ParseStatus.parsed,
      );

      expect(capture, isNotNull);
      expect(capture!.packageName, 'com.bank.app');
      expect(capture.rawTitle, 'Biến động số dư');
      expect(capture.rawText, 'Tài khoản -500,000 VND');
      expect(capture.amount, 500000);
      expect(capture.direction, CaptureDirection.expense);
      expect(capture.parseStatus, ParseStatus.parsed);
      expect(capture.status, CaptureStatus.pending);
      expect(capture.resultingTxnId, isNull);
    });

    test('resolves suggestedWalletId from wallet packageName match', () async {
      final wid = await _addWallet(repo,
          name: 'Ngân hàng', packageName: 'com.vcb.app');

      final capture = await repo.insertCapture(
        packageName: 'com.vcb.app',
        rawText: 'Số dư: 1,000,000 VND',
        capturedAt: DateTime(2024, 6, 1),
      );

      expect(capture!.suggestedWalletId, wid,
          reason: 'should resolve wallet by packageName');
    });

    test('leaves suggestedWalletId null when no wallet matches', () async {
      await _addWallet(repo, packageName: 'com.other.bank');

      final capture = await repo.insertCapture(
        packageName: 'com.unknown.app',
        rawText: 'Giao dịch thành công',
        capturedAt: DateTime(2024, 6, 1),
      );

      expect(capture!.suggestedWalletId, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('dedup', () {
    test('second identical capture within 2 minutes is skipped', () async {
      final t0 = DateTime(2024, 6, 1, 12, 0, 0);
      final t1 = t0.add(const Duration(seconds: 90)); // 1.5 min later

      final first = await repo.insertCapture(
        packageName: 'com.bank.app',
        rawText: 'Thanh toán 200,000 VND',
        capturedAt: t0,
      );
      final second = await repo.insertCapture(
        packageName: 'com.bank.app',
        rawText: 'Thanh toán 200,000 VND',
        capturedAt: t1,
      );

      expect(first, isNotNull, reason: 'first capture must be inserted');
      expect(second, isNull, reason: 'duplicate within window must be skipped');
    });

    test('same text AFTER the 2-minute window is not a duplicate', () async {
      final t0 = DateTime(2024, 6, 1, 12, 0, 0);
      final t1 = t0.add(const Duration(minutes: 3));

      await repo.insertCapture(
        packageName: 'com.bank.app',
        rawText: 'Thanh toán 200,000 VND',
        capturedAt: t0,
      );
      final second = await repo.insertCapture(
        packageName: 'com.bank.app',
        rawText: 'Thanh toán 200,000 VND',
        capturedAt: t1,
      );

      expect(second, isNotNull, reason: 'capture after window must be inserted');
    });

    test('different notification text is not a duplicate', () async {
      final t0 = DateTime(2024, 6, 1, 12, 0, 0);

      await repo.insertCapture(
        packageName: 'com.bank.app',
        rawText: 'Thanh toán 200,000 VND',
        capturedAt: t0,
      );
      final second = await repo.insertCapture(
        packageName: 'com.bank.app',
        rawText: 'Nhận 500,000 VND', // different text
        capturedAt: t0.add(const Duration(seconds: 10)),
      );

      expect(second, isNotNull, reason: 'different text must be inserted');
    });

    test('normalization: whitespace and case variations match', () async {
      final t0 = DateTime(2024, 6, 1, 12, 0, 0);
      final t1 = t0.add(const Duration(seconds: 30));

      final first = await repo.insertCapture(
        packageName: 'com.bank.app',
        rawText: '  THANH TOÁN  200,000  VND  ', // extra spaces + upper
        capturedAt: t0,
      );
      final second = await repo.insertCapture(
        packageName: 'com.bank.app',
        rawText: 'thanh toán 200,000 vnd', // normalized form
        capturedAt: t1,
      );

      expect(first, isNotNull);
      expect(second, isNull,
          reason: 'normalized text must match the original trimmed/lowercased');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('confirmCapture', () {
    Future<NotificationCapture> seedCapture({
      CaptureDirection direction = CaptureDirection.expense,
    }) async {
      return (await repo.insertCapture(
        packageName: 'com.bank.app',
        rawText: 'Giao dịch ${DateTime.now().microsecondsSinceEpoch}',
        capturedAt: DateTime.now(),
        direction: direction,
      ))!;
    }

    test('creates transaction with bankNotification + affectsBalance=true', () async {
      final wid = await _addWallet(repo, initialBalance: 1000000);
      final capture = await seedCapture(direction: CaptureDirection.expense);

      await repo.confirmCapture(capture.id,
          walletId: wid, amount: 200000, direction: CaptureDirection.expense);

      final txns = await db.allTxns();
      expect(txns, hasLength(1));
      final txn = txns.first;
      expect(txn.source, SourceType.bankNotification,
          reason: 'source must be bankNotification');
      expect(txn.affectsBalance, isTrue,
          reason: 'affectsBalance must be true');
      expect(txn.imported, isFalse,
          reason: 'imported must be false');
    });

    test('income → earning type', () async {
      final wid = await _addWallet(repo);
      final capture = await seedCapture(direction: CaptureDirection.income);

      await repo.confirmCapture(capture.id,
          walletId: wid, amount: 300000, direction: CaptureDirection.income);

      final txns = await db.allTxns();
      expect(txns.first.type, TxTypes.earning);
    });

    test('expense → spending type', () async {
      final wid = await _addWallet(repo, initialBalance: 1000000);
      final capture = await seedCapture(direction: CaptureDirection.expense);

      await repo.confirmCapture(capture.id,
          walletId: wid, amount: 100000, direction: CaptureDirection.expense);

      final txns = await db.allTxns();
      expect(txns.first.type, TxTypes.spending);
    });

    test('marks capture confirmed and sets resultingTxnId', () async {
      final wid = await _addWallet(repo, initialBalance: 1000000);
      final capture = await seedCapture(direction: CaptureDirection.expense);

      await repo.confirmCapture(capture.id,
          walletId: wid, amount: 50000, direction: CaptureDirection.expense);

      final updated = await (db.select(db.notificationCaptures)
            ..where((c) => c.id.equals(capture.id)))
          .getSingle();
      final txns = await db.allTxns();

      expect(updated.status, CaptureStatus.confirmed);
      expect(updated.resultingTxnId, txns.first.id,
          reason: 'resultingTxnId must point to the created transaction');
    });

    test('is atomic — both txn and capture update committed together', () async {
      final wid = await _addWallet(repo, initialBalance: 1000000);
      final capture = await seedCapture(direction: CaptureDirection.expense);

      await repo.confirmCapture(capture.id,
          walletId: wid, amount: 75000, direction: CaptureDirection.expense);

      // If atomicity failed, one side would be missing.
      final txnCount = (await db.allTxns()).length;
      final confirmed = await (db.select(db.notificationCaptures)
            ..where((c) =>
                c.id.equals(capture.id) &
                c.status.equals(CaptureStatus.confirmed.name)))
          .getSingleOrNull();

      expect(txnCount, 1);
      expect(confirmed, isNotNull);
    });

    test('expense exceeding tracked balance succeeds — balance goes negative', () async {
      final wid = await _addWallet(repo, initialBalance: 100000);
      final capture = await seedCapture(direction: CaptureDirection.expense);

      // 500,000 expense on a wallet with only 100,000 balance.
      // Manual addSpending would throw OverspendException here.
      await expectLater(
        repo.confirmCapture(capture.id,
            walletId: wid, amount: 500000, direction: CaptureDirection.expense),
        completes,
        reason: 'bank confirm must not throw OverspendException',
      );

      final balance = await db.sqlBalance(wid);
      expect(balance, -400000,
          reason: 'balance must go negative after bank confirm overspend');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('dismissCapture', () {
    test('marks capture dismissed and creates no transaction', () async {
      final capture = (await repo.insertCapture(
        packageName: 'com.bank.app',
        rawText: 'Giao dịch không cần thiết',
        capturedAt: DateTime.now(),
      ))!;

      await repo.dismissCapture(capture.id);

      final updated = await (db.select(db.notificationCaptures)
            ..where((c) => c.id.equals(capture.id)))
          .getSingle();
      final txns = await db.allTxns();

      expect(updated.status, CaptureStatus.dismissed);
      expect(txns, isEmpty, reason: 'no transaction must be created on dismiss');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('watchPendingCaptures / pendingCaptureCount', () {
    Future<NotificationCapture> insert(String text) async =>
        (await repo.insertCapture(
          packageName: 'com.bank.app',
          rawText: text,
          capturedAt: DateTime.now(),
        ))!;

    test('reflects inserts', () async {
      expect(await repo.watchPendingCaptures().first, isEmpty);

      await insert('tx A');
      await insert('tx B');

      final pending = await repo.watchPendingCaptures().first;
      expect(pending, hasLength(2));
    });

    test('confirmed captures do not appear in pending', () async {
      final wid = await _addWallet(repo, initialBalance: 1000000);
      final cap = await insert('tx to confirm');

      await repo.confirmCapture(cap.id,
          walletId: wid, amount: 10000, direction: CaptureDirection.expense);

      final pending = await repo.watchPendingCaptures().first;
      expect(pending, isEmpty);
    });

    test('dismissed captures do not appear in pending', () async {
      final cap = await insert('tx to dismiss');
      await repo.dismissCapture(cap.id);

      final pending = await repo.watchPendingCaptures().first;
      expect(pending, isEmpty);
    });

    test('pendingCaptureCount matches pending list length', () async {
      await insert('tx 1');
      await insert('tx 2');
      await insert('tx 3');

      final count = await repo.pendingCaptureCount().first;
      expect(count, 3);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('migration 4→5', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('drift_5a_migration_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('preserves wallet balances and creates new table / column / index',
        () async {
      final file = File('${tempDir.path}/test.sqlite');
      final ts = DateTime(2024, 3, 1).millisecondsSinceEpoch ~/ 1000;

      // ── Seed v4 database ───────────────────────────────────────────────────
      final v4 = _V4Db(NativeDatabase(file));

      await v4.customStatement(
          'INSERT INTO wallets (id, name, initial_balance, type) VALUES (?,?,?,?)',
          ['w1', 'Cash', 500000, 'cash']);
      await v4.customStatement(
          'INSERT INTO wallets (id, name, initial_balance, type) VALUES (?,?,?,?)',
          ['w2', 'Bank', 0, 'bank']);

      // earning on w1: +200,000
      await v4.customStatement(
          'INSERT INTO txns (id, type, amount, wallet_id, timestamp, created_at, source, affects_balance) VALUES (?,?,?,?,?,?,?,?)',
          ['t1', 'earning', 200000, 'w1', ts, ts, 'manual', 1]);
      // spending on w1: -100,000
      await v4.customStatement(
          'INSERT INTO txns (id, type, amount, wallet_id, timestamp, created_at, source, affects_balance) VALUES (?,?,?,?,?,?,?,?)',
          ['t2', 'spending', 100000, 'w1', ts, ts, 'manual', 1]);
      // transfer w1→w2: -50,000 from w1, +50,000 to w2
      await v4.customStatement(
          'INSERT INTO txns (id, type, amount, wallet_id, wallet_to_id, timestamp, created_at, source, affects_balance) VALUES (?,?,?,?,?,?,?,?,?)',
          ['t3', 'transfer', 50000, 'w1', 'w2', ts, ts, 'manual', 1]);

      await v4.close();

      // ── Open with v5 AppDatabase — triggers 4→5 migration ─────────────────
      final db = AppDatabase.forTesting(NativeDatabase(file));
      final repo = FinanceRepository(db);

      // ── Balance preservation ───────────────────────────────────────────────
      // w1: 500000 + 200000 - 100000 - 50000 = 550000
      // w2: 0 + 50000 = 50000
      expect(await db.sqlBalance('w1'), 550000,
          reason: 'w1 balance must be unchanged after migration');
      expect(await db.sqlBalance('w2'), 50000,
          reason: 'w2 balance must be unchanged after migration');

      // ── notification_captures table exists ────────────────────────────────
      await expectLater(
        db.customSelect('SELECT 1 FROM notification_captures LIMIT 1').get(),
        completes,
        reason: 'notification_captures table must exist after migration',
      );

      // ── wallets.package_name column exists ────────────────────────────────
      await expectLater(
        db.customSelect('SELECT package_name FROM wallets LIMIT 1').get(),
        completes,
        reason: 'wallets.package_name column must exist after migration',
      );

      // ── Existing wallets still have NULL package_name ─────────────────────
      final wallets = await db.allWallets();
      expect(wallets.every((w) => w.packageName == null), isTrue,
          reason: 'migrated wallets must have null packageName');

      // ── Unique index: same package_name rejected for two wallets ──────────
      await repo.addWallet(name: 'W3', initialBalance: 0);
      final w3 = (await db.allWallets()).firstWhere((w) => w.name == 'W3');
      await (db.update(db.wallets)..where((w) => w.id.equals(w3.id)))
          .write(const WalletsCompanion(packageName: Value('com.test.bank')));

      await repo.addWallet(name: 'W4', initialBalance: 0);
      final w4 = (await db.allWallets()).firstWhere((w) => w.name == 'W4');
      await expectLater(
        (db.update(db.wallets)..where((w) => w.id.equals(w4.id)))
            .write(const WalletsCompanion(
                packageName: Value('com.test.bank'))),
        throwsA(anything),
        reason: 'unique index must reject duplicate non-null packageName',
      );

      await db.close();
    });
  });
}
