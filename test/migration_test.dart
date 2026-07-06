import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfinance/data/database.dart';
import 'package:myfinance/models/domain.dart';
import 'package:myfinance/repositories/finance_repository.dart';

// Exact v2 CREATE TABLE SQL from schemas/2.json (dialect: sqlite).
const _kWallets =
    'CREATE TABLE IF NOT EXISTS "wallets" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, '
    '"initial_balance" INTEGER NOT NULL DEFAULT 0, "type" TEXT NOT NULL DEFAULT \'cash\', '
    'PRIMARY KEY ("id"))';

const _kTxns =
    'CREATE TABLE IF NOT EXISTS "txns" ("id" TEXT NOT NULL, "type" TEXT NOT NULL, '
    '"amount" INTEGER NOT NULL, "description" TEXT NULL, "wallet_id" TEXT NOT NULL, '
    '"wallet_to_id" TEXT NULL, "category" TEXT NULL, "timestamp" INTEGER NOT NULL, '
    '"created_at" INTEGER NOT NULL, '
    '"imported" INTEGER NOT NULL DEFAULT 0 CHECK ("imported" IN (0, 1)), '
    '"starred" INTEGER NOT NULL DEFAULT 0 CHECK ("starred" IN (0, 1)), '
    '"wallet_from_name" TEXT NULL, "wallet_to_name" TEXT NULL, '
    'PRIMARY KEY ("id"))';

const _kAppCategories =
    'CREATE TABLE IF NOT EXISTS "app_categories" ("id" TEXT NOT NULL, '
    '"label" TEXT NOT NULL, "kind" TEXT NOT NULL, '
    '"threshold" INTEGER NOT NULL DEFAULT 0, '
    '"is_default" INTEGER NOT NULL DEFAULT 0 CHECK ("is_default" IN (0, 1)), '
    '"archived" INTEGER NOT NULL DEFAULT 0 CHECK ("archived" IN (0, 1)), '
    '"sort_order" INTEGER NOT NULL DEFAULT 0, PRIMARY KEY ("id"))';

/// Minimal Drift database that opens at schema version 2 using the exact v2 schema.
/// Used to seed pre-migration data before opening with the real AppDatabase.
class _V2Db extends GeneratedDatabase {
  _V2Db(super.e);

  @override
  int get schemaVersion => 2;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      const <DatabaseSchemaEntity>[];

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await customStatement(_kWallets);
          await customStatement(_kTxns);
          await customStatement(_kAppCategories);
        },
      );
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('drift_migration_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('v2→v3 migration backfills source/affectsBalance and preserves wallet balances',
      () async {
    final file = File('${tempDir.path}/test.sqlite');
    final ts = DateTime(2024, 1, 1).millisecondsSinceEpoch;

    // ── Phase 1: Create and seed a v2 database ─────────────────────────────────
    final v2 = _V2Db(NativeDatabase(file));

    await v2.customStatement(
        'INSERT INTO wallets (id, name, initial_balance, type) VALUES (?, ?, ?, ?)',
        ['w1', 'Cash', 500000, 'cash']);
    await v2.customStatement(
        'INSERT INTO wallets (id, name, initial_balance, type) VALUES (?, ?, ?, ?)',
        ['w2', 'Savings', 0, 'bank']);

    // t1: native spending — imported=0
    await v2.customStatement(
        'INSERT INTO txns (id, type, amount, wallet_id, "timestamp", created_at, imported, starred) VALUES (?,?,?,?,?,?,?,?)',
        ['t1', 'spending', 100000, 'w1', ts, ts, 0, 0]);
    // t2: native earning — imported=0
    await v2.customStatement(
        'INSERT INTO txns (id, type, amount, wallet_id, "timestamp", created_at, imported, starred) VALUES (?,?,?,?,?,?,?,?)',
        ['t2', 'earning', 200000, 'w1', ts, ts, 0, 0]);
    // t3: imported spending — imported=1
    await v2.customStatement(
        'INSERT INTO txns (id, type, amount, wallet_id, "timestamp", created_at, imported, starred) VALUES (?,?,?,?,?,?,?,?)',
        ['t3', 'spending', 50000, 'w1', ts, ts, 1, 0]);
    // t4: imported earning — imported=1
    await v2.customStatement(
        'INSERT INTO txns (id, type, amount, wallet_id, "timestamp", created_at, imported, starred) VALUES (?,?,?,?,?,?,?,?)',
        ['t4', 'earning', 30000, 'w1', ts, ts, 1, 0]);
    // t5: imported transfer (covers the case where transfers were imported) — imported=1
    await v2.customStatement(
        'INSERT INTO txns (id, type, amount, wallet_id, wallet_to_id, "timestamp", created_at, imported, starred) VALUES (?,?,?,?,?,?,?,?,?)',
        ['t5', 'transfer', 80000, 'w1', 'w2', ts, ts, 1, 0]);

    await v2.close();

    // ── Phase 2: Reopen with AppDatabase — triggers onUpgrade(2→3) ────────────
    final db = AppDatabase.forTesting(NativeDatabase(file));

    // ── Phase 3: Assert backfill ──────────────────────────────────────────────
    final txnMap = {for (final t in await db.allTxns()) t.id: t};

    // Non-imported rows → source=manual, affectsBalance=true
    expect(txnMap['t1']!.source, SourceType.manual, reason: 't1 native spending');
    expect(txnMap['t1']!.affectsBalance, isTrue);
    expect(txnMap['t2']!.source, SourceType.manual, reason: 't2 native earning');
    expect(txnMap['t2']!.affectsBalance, isTrue);

    // Imported rows → source=csvImport, affectsBalance=false
    expect(txnMap['t3']!.source, SourceType.csvImport, reason: 't3 imported spending');
    expect(txnMap['t3']!.affectsBalance, isFalse);
    expect(txnMap['t4']!.source, SourceType.csvImport, reason: 't4 imported earning');
    expect(txnMap['t4']!.affectsBalance, isFalse);

    // Imported transfer also gets csvImport/false
    expect(txnMap['t5']!.source, SourceType.csvImport, reason: 't5 imported transfer');
    expect(txnMap['t5']!.affectsBalance, isFalse,
        reason: 'imported transfer must not affect balance');

    // ── Phase 4: Assert balance preservation ─────────────────────────────────
    // Pre-migration: w1 balance = 500000 - 100000 (t1) + 200000 (t2) = 600000
    //                (t3, t4, t5 were excluded because imported=true)
    // Post-migration: same result — t1/t2 have affectsBalance=true; t3/t4/t5 don't
    final repo = FinanceRepository(db);
    final allTxns = await db.allTxns();
    final wallets = {for (final w in await db.allWallets()) w.id: w};

    expect(repo.balanceOf(wallets['w1']!, allTxns), 600000,
        reason: 'w1 balance must be unchanged after migration');
    expect(repo.balanceOf(wallets['w2']!, allTxns), 0,
        reason: 'w2 received no affectsBalance transactions');

    await db.close();
  });
}
