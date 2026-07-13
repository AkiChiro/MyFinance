import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/domain.dart';

part 'database.g.dart';

// ── Tables ────────────────────────────────────────────────────────────────────

class Wallets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get initialBalance => integer().withDefault(const Constant(0))();
  TextColumn get type => text().withDefault(const Constant('cash'))();
  // nullable: at most one wallet maps to a given bank app package (ADR-0014).
  TextColumn get packageName => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Txn')
class Txns extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()(); // spending | earning | transfer
  IntColumn get amount => integer()(); // VND, whole numbers
  TextColumn get description => text().nullable()();
  TextColumn get walletId => text()();
  TextColumn get walletToId => text().nullable()(); // transfer only
  TextColumn get category => text().nullable()(); // null for transfer
  DateTimeColumn get timestamp => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get imported => boolean().withDefault(const Constant(false))();
  // §2 additions
  BoolColumn get starred => boolean().withDefault(const Constant(false))();
  /// Snapshot of the source wallet name at CSV-import time (for merged rows).
  TextColumn get walletFromName => text().nullable()();
  /// Snapshot of the destination wallet name at CSV-import time.
  TextColumn get walletToName => text().nullable()();
  // §3 additions (Phase 3)
  TextColumn get source =>
      textEnum<SourceType>().withDefault(const Constant('manual'))();
  BoolColumn get affectsBalance => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Persistent capture table for bank notification proposals (ADR-0013).
/// Parsed fields (amount, direction, parseStatus) are populated by later slices.
@DataClassName('NotificationCapture')
class NotificationCaptures extends Table {
  TextColumn get id => text()();
  TextColumn get packageName => text()();
  TextColumn get rawTitle => text().nullable()();
  TextColumn get rawText => text()();
  DateTimeColumn get capturedAt => dateTime()();

  // Parsed by later slice (5b parser):
  IntColumn get amount => integer().nullable()();
  TextColumn get direction => textEnum<CaptureDirection>().nullable()();
  TextColumn get parseStatus =>
      textEnum<ParseStatus>().withDefault(const Constant('unparsed'))();

  // Suggestions (nullable, resolved on insert / by later slices):
  TextColumn get suggestedWalletId => text().nullable()();
  TextColumn get suggestedCategory => text().nullable()();

  // Lifecycle:
  TextColumn get status =>
      textEnum<CaptureStatus>().withDefault(const Constant('pending'))();
  TextColumn get resultingTxnId => text().nullable()();

  // Composite dedup key: packageName + \x1e + normalizedText (not a hash —
  // the full string is stored so the dedup query is a plain equality check).
  TextColumn get dedupKey => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// User-editable (and default) transaction categories.
/// id = stable string key ('necessities', 'food', …, or uuid for user-created).
@DataClassName('AppCategory')
class AppCategories extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()();
  TextColumn get kind => text()(); // 'spending' | 'earning'
  IntColumn get threshold => integer().withDefault(const Constant(0))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// ── AnalyticsBundle ───────────────────────────────────────────────────────────

/// Pre-aggregated analytics data for a given month, produced by SQL aggregates.
/// Fields are millisecond-epoch-aligned totals; category maps use the same
/// NULL-fallback as the Dart fold ('others' / 'others_earn').
class AnalyticsBundle {
  const AnalyticsBundle({
    required this.currSpending,
    required this.currEarning,
    required this.prevSpending,
    required this.prevEarning,
    required this.yearSpending,
    required this.yearEarning,
    required this.spendByCat,
    required this.earnByCat,
  });

  final int currSpending;
  final int currEarning;
  final int prevSpending;
  final int prevEarning;
  final int yearSpending;
  final int yearEarning;
  final Map<String, int> spendByCat;
  final Map<String, int> earnByCat;
}

// ── Database ──────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [Wallets, Txns, AppCategories, NotificationCaptures])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// In-memory database for unit tests — skips the file-system open.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedCategories();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(txns, txns.starred);
            await m.addColumn(txns, txns.walletFromName);
            await m.addColumn(txns, txns.walletToName);
            await m.createTable(appCategories);
            await _seedCategories();
          }
          if (from < 3) {
            await m.addColumn(txns, txns.source);
            await m.addColumn(txns, txns.affectsBalance);
            // Backfill from imported flag:
            //   imported=true  → source='csvImport', affects_balance=0
            //   imported=false → source='manual',    affects_balance=1
            await customStatement(
              "UPDATE txns SET source = 'csvImport', affects_balance = 0 WHERE imported = 1",
            );
          }
          if (from < 4) {
            // Phase 4: add partial indexes for the balance and analytics aggregates.
            // Partial indexes keep these small (only affects_balance=1 rows matter).
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
          }
          if (from < 5) {
            // Phase 5a: bank capture table + wallet↔package association (ADR-0013/14).
            await m.addColumn(wallets, wallets.packageName);
            await m.createTable(notificationCaptures);
            // Partial unique index: SQLite allows multiple NULLs, so wallets without
            // a package association coexist freely; only non-null values are unique.
            await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_wallets_pkg ON wallets(package_name) WHERE package_name IS NOT NULL',
            );
          }
          if (from < 6) {
            // Issue #4: user-controlled wallet ordering.
            // Use raw SQL — build_runner hasn't regenerated wallets.sortOrder yet.
            await customStatement(
              'ALTER TABLE wallets ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
            );
            // Seed initial order alphabetically to match the previous sort.
            await customStatement(
              'UPDATE wallets SET sort_order = (SELECT COUNT(*) FROM wallets w2 WHERE w2.name < wallets.name)',
            );
          }
        },
      );

  // ── Category seeding ────────────────────────────────────────────────────────

  Future<void> _seedCategories() async {
    final seeds = [
      // spending
      ('necessities', 'Thiết yếu', 'spending', 500000, 0),
      ('food', 'Ăn uống', 'spending', 100000, 1),
      ('hobbies', 'Sở thích', 'spending', 1000000, 2),
      ('others', 'Khác', 'spending', 200000, 3),
      // earning
      ('provided', 'Chu cấp', 'earning', 0, 0),
      ('self_earned', 'Tự kiếm', 'earning', 0, 1),
      ('others_earn', 'Khác', 'earning', 0, 2),
    ];
    for (final (id, label, kind, threshold, order) in seeds) {
      await into(appCategories).insertOnConflictUpdate(
        AppCategoriesCompanion.insert(
          id: id,
          label: label,
          kind: kind,
          threshold: Value(threshold),
          isDefault: const Value(true),
          sortOrder: Value(order),
        ),
      );
    }
  }

  // ── Wallets ─────────────────────────────────────────────────────────────────

  // Raw SQL keeps sort_order ordering without needing the generated accessor.
  Stream<List<Wallet>> watchWallets() =>
      customSelect(
        'SELECT * FROM wallets ORDER BY sort_order, name',
        readsFrom: {wallets},
      ).watch().map((rows) => rows.map((r) => wallets.map(r.data)).toList());

  Future<void> updateWalletsOrder(List<String> orderedIds) =>
      transaction(() async {
        for (var i = 0; i < orderedIds.length; i++) {
          await customStatement(
            'UPDATE wallets SET sort_order = ? WHERE id = ?',
            [i, orderedIds[i]],
          );
        }
      });

  Future<List<Wallet>> allWallets() => select(wallets).get();

  Future<Wallet?> walletById(String id) =>
      (select(wallets)..where((w) => w.id.equals(id))).getSingleOrNull();

  // ── Transactions ─────────────────────────────────────────────────────────────

  Stream<List<Txn>> watchTxns() => (select(txns)
        ..orderBy([
          (t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)
        ]))
      .watch();

  Future<List<Txn>> allTxns() => select(txns).get();

  Future<List<Txn>> nativeTxns() =>
      (select(txns)..where((t) => t.affectsBalance.equals(true))).get();

  // ── SQL balance queries ───────────────────────────────────────────────────────
  //
  // Transfers have a dual role: a single row subtracts from walletId and adds
  // to walletToId. A plain GROUP BY walletId misses the incoming side.
  // Both queries below use UNION ALL to split each transaction into signed
  // (wid, delta) contributions, then SUM by wallet.

  /// Reactive stream of {walletId → derived balance} for all wallets.
  /// Used by the wallet list UI.
  Stream<Map<String, int>> watchWalletBalances() =>
      customSelect(_kAllBalancesSql, readsFrom: {wallets, txns})
          .watch()
          .map((rows) => {
                for (final r in rows)
                  r.read<String>('id'): r.read<int>('balance')
              });

  /// One-shot single-wallet balance. Pass [excludeId] on the edit path
  /// (overspend check must ignore the transaction being updated).
  Future<int> sqlBalance(String walletId, {String? excludeId}) async {
    final sql = excludeId == null ? _kSingleBalanceSql : _kSingleBalanceExcludeSql;
    final List<Variable<Object>> vars;
    if (excludeId == null) {
      vars = [
        Variable<String>(walletId),
        Variable<String>(walletId),
        Variable<String>(walletId),
        Variable<String>(walletId),
        Variable<String>(walletId),
      ];
    } else {
      vars = [
        Variable<String>(walletId), Variable<String>(excludeId),
        Variable<String>(walletId), Variable<String>(excludeId),
        Variable<String>(walletId), Variable<String>(excludeId),
        Variable<String>(walletId), Variable<String>(excludeId),
        Variable<String>(walletId),
      ];
    }
    final rows =
        await customSelect(sql, variables: vars, readsFrom: {wallets, txns})
            .get();
    return rows.isEmpty ? 0 : rows.single.read<int>('balance');
  }

  // ── SQL analytics queries ─────────────────────────────────────────────────────

  /// Reactive stream of pre-aggregated analytics for [month].
  /// Re-emits whenever the txns table changes.
  Stream<AnalyticsBundle> watchAnalyticsBundle(DateTime month) async* {
    yield await _buildAnalyticsBundle(month);
    await for (final _ in tableUpdates(TableUpdateQuery.onTable(txns))) {
      yield await _buildAnalyticsBundle(month);
    }
  }

  Future<AnalyticsBundle> _buildAnalyticsBundle(DateTime month) async {
    // All boundaries are local-time Unix SECONDS (Drift 2.x stores DateTimeColumn
    // as millisecondsSinceEpoch ~/ 1000, reads back as seconds * 1000).
    // Using seconds matches the stored integer type exactly, preserving the same
    // month/year boundary semantics as the Dart fold's t.timestamp.year/.month.
    final currStart = DateTime(month.year, month.month).millisecondsSinceEpoch ~/ 1000;
    final currEnd =
        DateTime(month.year, month.month + 1).millisecondsSinceEpoch ~/ 1000;
    final prevStart =
        DateTime(month.year, month.month - 1).millisecondsSinceEpoch ~/ 1000;
    final prevEnd = currStart; // prevMonth ends where currMonth begins
    final yearStart = DateTime(month.year, 1).millisecondsSinceEpoch ~/ 1000;
    final yearEnd = DateTime(month.year + 1, 1).millisecondsSinceEpoch ~/ 1000;

    final totRow = await customSelect(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN timestamp>=? AND timestamp<? AND type='spending' THEN amount END), 0) AS curr_sp,
        COALESCE(SUM(CASE WHEN timestamp>=? AND timestamp<? AND type='earning'  THEN amount END), 0) AS curr_ea,
        COALESCE(SUM(CASE WHEN timestamp>=? AND timestamp<? AND type='spending' THEN amount END), 0) AS prev_sp,
        COALESCE(SUM(CASE WHEN timestamp>=? AND timestamp<? AND type='earning'  THEN amount END), 0) AS prev_ea,
        COALESCE(SUM(CASE WHEN timestamp>=? AND timestamp<? AND type='spending' THEN amount END), 0) AS year_sp,
        COALESCE(SUM(CASE WHEN timestamp>=? AND timestamp<? AND type='earning'  THEN amount END), 0) AS year_ea
      FROM txns
      WHERE affects_balance=1 AND type!='transfer'
      ''',
      variables: [
        Variable<int>(currStart), Variable<int>(currEnd),
        Variable<int>(currStart), Variable<int>(currEnd),
        Variable<int>(prevStart), Variable<int>(prevEnd),
        Variable<int>(prevStart), Variable<int>(prevEnd),
        Variable<int>(yearStart), Variable<int>(yearEnd),
        Variable<int>(yearStart), Variable<int>(yearEnd),
      ],
      readsFrom: {txns},
    ).getSingle();

    final spRows = await customSelect(
      '''
      SELECT COALESCE(category, 'others') AS cat, SUM(amount) AS total
      FROM txns
      WHERE affects_balance=1 AND type='spending' AND timestamp>=? AND timestamp<?
      GROUP BY cat
      ''',
      variables: [Variable<int>(currStart), Variable<int>(currEnd)],
      readsFrom: {txns},
    ).get();

    final eaRows = await customSelect(
      '''
      SELECT COALESCE(category, 'others_earn') AS cat, SUM(amount) AS total
      FROM txns
      WHERE affects_balance=1 AND type='earning' AND timestamp>=? AND timestamp<?
      GROUP BY cat
      ''',
      variables: [Variable<int>(currStart), Variable<int>(currEnd)],
      readsFrom: {txns},
    ).get();

    return AnalyticsBundle(
      currSpending: totRow.read<int>('curr_sp'),
      currEarning: totRow.read<int>('curr_ea'),
      prevSpending: totRow.read<int>('prev_sp'),
      prevEarning: totRow.read<int>('prev_ea'),
      yearSpending: totRow.read<int>('year_sp'),
      yearEarning: totRow.read<int>('year_ea'),
      spendByCat: {
        for (final r in spRows) r.read<String>('cat'): r.read<int>('total')
      },
      earnByCat: {
        for (final r in eaRows) r.read<String>('cat'): r.read<int>('total')
      },
    );
  }

  // ── Categories ────────────────────────────────────────────────────────────────

  Stream<List<AppCategory>> watchActiveCategories(String kind) =>
      (select(appCategories)
            ..where((c) => c.kind.equals(kind) & c.archived.equals(false))
            ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
          .watch();

  Future<List<AppCategory>> activeCategories(String kind) =>
      (select(appCategories)
            ..where((c) => c.kind.equals(kind) & c.archived.equals(false))
            ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
          .get();

  Future<List<AppCategory>> allActiveCategories() =>
      (select(appCategories)
            ..where((c) => c.archived.equals(false))
            ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
          .get();

  Future<Map<String, int>> categoryThresholds(String kind) async {
    final cats = await activeCategories(kind);
    return {for (final c in cats) c.id: c.threshold};
  }

  // ── NotificationCaptures ─────────────────────────────────────────────────────

  Stream<List<NotificationCapture>> watchPendingCaptures() =>
      (select(notificationCaptures)
            ..where((c) => c.status.equals(CaptureStatus.pending.name))
            ..orderBy([
              (c) =>
                  OrderingTerm(expression: c.capturedAt, mode: OrderingMode.desc)
            ]))
          .watch();

  Stream<int> pendingCaptureCount() =>
      watchPendingCaptures().map((list) => list.length);

  Future<Wallet?> walletByPackageName(String pkgName) =>
      (select(wallets)..where((w) => w.packageName.equals(pkgName)))
          .getSingleOrNull();

  // No archived filter — used for rendering labels on historical transactions
  // (including categories that have since been soft-deleted / archived).
  Stream<List<AppCategory>> watchAllCategories() =>
      (select(appCategories)
            ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
          .watch();

  Future<List<AppCategory>> allCategories() =>
      (select(appCategories)
            ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
          .get();
}

// ── Balance SQL constants ─────────────────────────────────────────────────────
//
// UNION ALL decomposes each transaction into signed (wid, delta) contributions,
// then groups by wallet so transfers are counted on both sides.

/// All wallets: returns one row per wallet with columns (id TEXT, balance INTEGER).
const _kAllBalancesSql = '''
  SELECT w.id AS id,
    w.initial_balance + COALESCE(c.delta_sum, 0) AS balance
  FROM wallets w
  LEFT JOIN (
    SELECT wid, SUM(delta) AS delta_sum FROM (
      SELECT wallet_id    AS wid,  amount AS delta FROM txns WHERE type='earning'  AND affects_balance=1
      UNION ALL
      SELECT wallet_id    AS wid, -amount AS delta FROM txns WHERE type='spending' AND affects_balance=1
      UNION ALL
      SELECT wallet_id    AS wid, -amount AS delta FROM txns WHERE type='transfer' AND affects_balance=1
      UNION ALL
      SELECT wallet_to_id AS wid,  amount AS delta FROM txns
        WHERE type='transfer' AND affects_balance=1 AND wallet_to_id IS NOT NULL
    ) GROUP BY wid
  ) c ON c.wid = w.id
''';

/// Single wallet (no excludeId). 5 positional params, all = walletId.
const _kSingleBalanceSql = '''
  SELECT w.initial_balance + COALESCE(c.delta_sum, 0) AS balance
  FROM wallets w
  LEFT JOIN (
    SELECT SUM(delta) AS delta_sum FROM (
      SELECT  amount AS delta FROM txns WHERE type='earning'  AND affects_balance=1 AND wallet_id=?
      UNION ALL
      SELECT -amount AS delta FROM txns WHERE type='spending' AND affects_balance=1 AND wallet_id=?
      UNION ALL
      SELECT -amount AS delta FROM txns WHERE type='transfer' AND affects_balance=1 AND wallet_id=?
      UNION ALL
      SELECT  amount AS delta FROM txns WHERE type='transfer' AND affects_balance=1 AND wallet_to_id=?
    )
  ) c
  WHERE w.id=?
''';

/// Single wallet excluding one id. 9 params: (walletId, excludeId) × 4 + walletId.
const _kSingleBalanceExcludeSql = '''
  SELECT w.initial_balance + COALESCE(c.delta_sum, 0) AS balance
  FROM wallets w
  LEFT JOIN (
    SELECT SUM(delta) AS delta_sum FROM (
      SELECT  amount AS delta FROM txns WHERE type='earning'  AND affects_balance=1 AND wallet_id=? AND id!=?
      UNION ALL
      SELECT -amount AS delta FROM txns WHERE type='spending' AND affects_balance=1 AND wallet_id=? AND id!=?
      UNION ALL
      SELECT -amount AS delta FROM txns WHERE type='transfer' AND affects_balance=1 AND wallet_id=? AND id!=?
      UNION ALL
      SELECT  amount AS delta FROM txns WHERE type='transfer' AND affects_balance=1 AND wallet_to_id=? AND id!=?
    )
  ) c
  WHERE w.id=?
''';

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'myfinance.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
