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
  // Unix seconds; when set, only txns at or after this timestamp affect the balance.
  IntColumn get balanceCutoffAt => integer().nullable()();

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
  // Unix seconds; when set, only txns at or after this timestamp count
  // toward this category's envelope allocated/spent totals (mirrors
  // wallets.balanceCutoffAt, applied per-category).
  IntColumn get envelopeCutoffAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Append-only history of per-(spending-)category budget-split percentages
/// (envelope budgeting). A new row is inserted whenever the user changes a
/// category's percentage; existing rows are never updated or deleted. Reads
/// pick the row with the largest effectiveFrom <= a given earning's own
/// timestamp (an "as-of" join) — this makes percentage changes non-
/// retroactive by construction: past envelope allocations are always
/// computed from whatever percentage was in effect at the time, never
/// today's percentage. Mirrors wallets.balanceCutoffAt's point-in-time
/// cutover idea, but as a full history instead of a single mutable column.
@DataClassName('CategoryBudgetEntry')
class CategoryBudgetHistory extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text()();
  IntColumn get percent => integer()(); // 0-100, whole percent of each earning
  IntColumn get effectiveFrom => integer()(); // Unix seconds

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

/// Per-category envelope status. [allocated] = earned share assigned to
/// this category so far (as-of budget-% join); [spent] = all-time spending
/// in this category. Both cumulative since forever, mirroring the balance
/// they used to collapse into.
class EnvelopeStatus {
  const EnvelopeStatus({required this.allocated, required this.spent});
  final int allocated;
  final int spent;
  int get balance => allocated - spent;
}

// ── Database ──────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [
  Wallets,
  Txns,
  AppCategories,
  NotificationCaptures,
  CategoryBudgetHistory,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// In-memory database for unit tests — skips the file-system open.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedCategories();
          await _seedBudgetPercents();
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
          if (from < 7) {
            // Per-wallet balance cutoff timestamp (Option C for balance reset).
            // NULL = no cutoff; txns from all time count toward balance.
            await customStatement(
              'ALTER TABLE wallets ADD COLUMN balance_cutoff_at INTEGER NULL',
            );
          }
          if (from < 8) {
            // Envelope budgeting: append-only percent-history table. Raw SQL —
            // database.g.dart doesn't have CategoryBudgetHistory's generated
            // accessor yet at migration-authoring time.
            await customStatement('''
              CREATE TABLE IF NOT EXISTS category_budget_history (
                id TEXT NOT NULL PRIMARY KEY,
                category_id TEXT NOT NULL,
                percent INTEGER NOT NULL,
                effective_from INTEGER NOT NULL
              )
            ''');
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_budget_history_cat_eff '
              'ON category_budget_history(category_id, effective_from)',
            );
            // Deliberately NO seed rows here. Percentage changes are never
            // retroactive (see the class doc-comment), so there is no
            // percentage that was ever "in effect" for pre-existing installs
            // — every category reads as unbudgeted until the user explicitly
            // sets one. Contrast with _seedBudgetPercents(), which only runs
            // for brand-new installs via onCreate.
          }
          if (from < 9) {
            // Per-category envelope cutoff timestamp (mirrors
            // balance_cutoff_at for wallets, applied per-category instead).
            // NULL = no cutoff; all-time txns count toward that category's
            // envelope.
            await customStatement(
              'ALTER TABLE app_categories ADD COLUMN envelope_cutoff_at INTEGER NULL',
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

  /// Default envelope-budget split for fresh installs only (never run on
  /// upgrade — see the `if (from < 8)` migration comment above). Mirrors the
  /// feature's own worked example: necessities 50 / food 15 / hobbies 20 /
  /// others 15 = 100%. effectiveFrom = 0 (Unix epoch) so the default applies
  /// to any earning timestamp — a fresh install has no prior history to
  /// preserve, so unlike the upgrade path there is no retroactivity concern.
  Future<void> _seedBudgetPercents() async {
    final seeds = [
      ('necessities', 50),
      ('food', 15),
      ('hobbies', 20),
      ('others', 15),
    ];
    for (final (categoryId, percent) in seeds) {
      await into(categoryBudgetHistory).insertOnConflictUpdate(
        CategoryBudgetHistoryCompanion.insert(
          id: '${categoryId}_seed',
          categoryId: categoryId,
          percent: percent,
          effectiveFrom: 0,
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
        // customStatement bypasses Drift's change tracker — notify explicitly.
        markTablesUpdated({wallets});
      });

  Future<List<Wallet>> allWallets() => select(wallets).get();

  Future<Wallet?> walletById(String id) =>
      (select(wallets)..where((w) => w.id.equals(id))).getSingleOrNull();

  Future<Txn?> txnById(String id) =>
      (select(txns)..where((t) => t.id.equals(id))).getSingleOrNull();

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
    // Fetch per-wallet cutoff (Unix seconds); 0 = include all transactions.
    final cutoffRows = await customSelect(
      'SELECT balance_cutoff_at FROM wallets WHERE id=?',
      variables: [Variable<String>(walletId)],
      readsFrom: {wallets},
    ).get();
    final cutoff = cutoffRows.isEmpty
        ? 0
        : (cutoffRows.single.readNullable<int>('balance_cutoff_at') ?? 0);

    final sql = excludeId == null ? _kSingleBalanceSql : _kSingleBalanceExcludeSql;
    final List<Variable<Object>> vars;
    if (excludeId == null) {
      vars = [
        Variable<String>(walletId), Variable<int>(cutoff),
        Variable<String>(walletId), Variable<int>(cutoff),
        Variable<String>(walletId), Variable<int>(cutoff),
        Variable<String>(walletId), Variable<int>(cutoff),
        Variable<String>(walletId),
      ];
    } else {
      vars = [
        Variable<String>(walletId), Variable<String>(excludeId), Variable<int>(cutoff),
        Variable<String>(walletId), Variable<String>(excludeId), Variable<int>(cutoff),
        Variable<String>(walletId), Variable<String>(excludeId), Variable<int>(cutoff),
        Variable<String>(walletId), Variable<String>(excludeId), Variable<int>(cutoff),
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
      WHERE type!='transfer'
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
      WHERE type='spending' AND timestamp>=? AND timestamp<?
      GROUP BY cat
      ''',
      variables: [Variable<int>(currStart), Variable<int>(currEnd)],
      readsFrom: {txns},
    ).get();

    final eaRows = await customSelect(
      '''
      SELECT COALESCE(category, 'others_earn') AS cat, SUM(amount) AS total
      FROM txns
      WHERE type='earning' AND timestamp>=? AND timestamp<?
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

  // ── Envelope budgeting ───────────────────────────────────────────────────────

  /// Every history row, unfolded (not just the current-effective value) —
  /// used by CSV export for a complete backup of the percent timeline.
  Future<List<CategoryBudgetEntry>> allCategoryBudgetHistory() =>
      select(categoryBudgetHistory).get();

  /// Current effective budget percent for every category that has ever had
  /// one configured, keyed by categoryId. A category with no history row is
  /// simply absent (callers treat missing as 0%). The table only grows on
  /// user edits (realistically tens of rows over the app's lifetime), so
  /// folding "latest effectiveFrom wins" in Dart is simpler than a SQL
  /// self-join and avoids an awkward tie-break on equal timestamps.
  Future<Map<String, int>> categoryBudgetPercents() async {
    final rows = await customSelect(
      'SELECT category_id, percent FROM category_budget_history ORDER BY effective_from',
      readsFrom: {categoryBudgetHistory},
    ).get();
    final result = <String, int>{};
    for (final r in rows) {
      result[r.read<String>('category_id')] = r.read<int>('percent');
    }
    return result;
  }

  Stream<Map<String, int>> watchCategoryBudgetPercents() async* {
    yield await categoryBudgetPercents();
    await for (final _
        in tableUpdates(TableUpdateQuery.onTable(categoryBudgetHistory))) {
      yield await categoryBudgetPercents();
    }
  }

  /// Reactive {categoryId → envelope balance}, cumulative since forever (not
  /// month-scoped like AnalyticsBundle). Re-emits on any change to txns,
  /// category_budget_history, or app_categories (e.g. editing a % or
  /// archiving a category in CategoriesPage) — watchAnalyticsBundle only
  /// listens to txns, which would silently miss those two.
  Stream<Map<String, EnvelopeStatus>> watchEnvelopeBalances() async* {
    yield await _buildEnvelopeBalances();
    await for (final _ in tableUpdates(TableUpdateQuery.allOf([
      TableUpdateQuery.onTable(txns),
      TableUpdateQuery.onTable(categoryBudgetHistory),
      TableUpdateQuery.onTable(appCategories),
    ]))) {
      yield await _buildEnvelopeBalances();
    }
  }

  Future<Map<String, EnvelopeStatus>> _buildEnvelopeBalances() async {
    // Earned share per active spending category. The inner correlated
    // subquery is an "as-of" join: the single most recent history row for
    // this category at-or-before each earning's own timestamp — this is
    // what makes a % change apply only to income recorded after the change.
    // COALESCE(...,0) means "no applicable row yet" contributes $0, so an
    // earning older than any configured percent needs no special-casing.
    // The envelope_cutoff_at filter mirrors wallets' balance_cutoff_at:
    // resetting a category's envelope excludes all earnings before the
    // reset, independent of every other category's own cutoff.
    final earnedRows = await customSelect('''
      SELECT c.id AS category_id,
        COALESCE((
          SELECT SUM(e.amount * COALESCE((
            SELECT bh.percent FROM category_budget_history bh
            WHERE bh.category_id = c.id AND bh.effective_from <= e.timestamp
            ORDER BY bh.effective_from DESC LIMIT 1
          ), 0))
          FROM txns e WHERE e.type = 'earning' AND e.affects_balance = 1
            AND e.timestamp >= COALESCE(c.envelope_cutoff_at, 0)
        ), 0) AS earned_x100
      FROM app_categories c
      WHERE c.kind = 'spending' AND c.archived = 0
      ''', readsFrom: {appCategories, txns, categoryBudgetHistory}).get();

    // Spent per category, ALL-TIME (subject to the same per-category cutoff
    // as the earned side above). Unlike analytics (which intentionally
    // ignores affects_balance — see docs/architecture.md), envelopes filter
    // affects_balance=1: they track real money only, not CSV context-only
    // rows. Transfers are excluded "for free" (never type='spending'). The
    // join is against COALESCE(t.category, 'others') — joining the raw
    // nullable column would drop null-category spending instead of
    // attributing it to the 'others' envelope.
    final spentRows = await customSelect('''
      SELECT COALESCE(t.category, 'others') AS cat, SUM(t.amount) AS total
      FROM txns t
      JOIN app_categories c ON c.id = COALESCE(t.category, 'others')
      WHERE t.type = 'spending' AND t.affects_balance = 1
        AND t.timestamp >= COALESCE(c.envelope_cutoff_at, 0)
      GROUP BY cat
      ''', readsFrom: {txns, appCategories}).get();
    final spentByCat = {
      for (final r in spentRows) r.read<String>('cat'): r.read<int>('total')
    };

    return {
      for (final r in earnedRows)
        r.read<String>('category_id'): EnvelopeStatus(
          allocated: r.read<int>('earned_x100') ~/ 100,
          spent: spentByCat[r.read<String>('category_id')] ?? 0,
        )
    };
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
/// Applies each wallet's balance_cutoff_at per-wallet so a reset on wallet A
/// does not affect wallet B's side of a shared transfer row.
const _kAllBalancesSql = '''
  SELECT w.id AS id,
    w.initial_balance + COALESCE(c.delta_sum, 0) AS balance
  FROM wallets w
  LEFT JOIN (
    SELECT wid, SUM(delta) AS delta_sum FROM (
      SELECT wallet_id    AS wid,  amount AS delta, timestamp AS ts FROM txns WHERE type='earning'  AND affects_balance=1
      UNION ALL
      SELECT wallet_id    AS wid, -amount AS delta, timestamp AS ts FROM txns WHERE type='spending' AND affects_balance=1
      UNION ALL
      SELECT wallet_id    AS wid, -amount AS delta, timestamp AS ts FROM txns WHERE type='transfer' AND affects_balance=1
      UNION ALL
      SELECT wallet_to_id AS wid,  amount AS delta, timestamp AS ts FROM txns
        WHERE type='transfer' AND affects_balance=1 AND wallet_to_id IS NOT NULL
    ) pairs
    JOIN wallets wc ON wc.id = pairs.wid
    WHERE pairs.ts >= COALESCE(wc.balance_cutoff_at, 0)
    GROUP BY wid
  ) c ON c.wid = w.id
''';

/// Single wallet (no excludeId). 9 positional params: (walletId, cutoff) × 4 + walletId.
const _kSingleBalanceSql = '''
  SELECT w.initial_balance + COALESCE(c.delta_sum, 0) AS balance
  FROM wallets w
  LEFT JOIN (
    SELECT SUM(delta) AS delta_sum FROM (
      SELECT  amount AS delta FROM txns WHERE type='earning'  AND affects_balance=1 AND wallet_id=?    AND timestamp>=?
      UNION ALL
      SELECT -amount AS delta FROM txns WHERE type='spending' AND affects_balance=1 AND wallet_id=?    AND timestamp>=?
      UNION ALL
      SELECT -amount AS delta FROM txns WHERE type='transfer' AND affects_balance=1 AND wallet_id=?    AND timestamp>=?
      UNION ALL
      SELECT  amount AS delta FROM txns WHERE type='transfer' AND affects_balance=1 AND wallet_to_id=? AND timestamp>=?
    )
  ) c
  WHERE w.id=?
''';

/// Single wallet excluding one id. 13 params: (walletId, excludeId, cutoff) × 4 + walletId.
const _kSingleBalanceExcludeSql = '''
  SELECT w.initial_balance + COALESCE(c.delta_sum, 0) AS balance
  FROM wallets w
  LEFT JOIN (
    SELECT SUM(delta) AS delta_sum FROM (
      SELECT  amount AS delta FROM txns WHERE type='earning'  AND affects_balance=1 AND wallet_id=? AND id!=? AND timestamp>=?
      UNION ALL
      SELECT -amount AS delta FROM txns WHERE type='spending' AND affects_balance=1 AND wallet_id=? AND id!=? AND timestamp>=?
      UNION ALL
      SELECT -amount AS delta FROM txns WHERE type='transfer' AND affects_balance=1 AND wallet_id=? AND id!=? AND timestamp>=?
      UNION ALL
      SELECT  amount AS delta FROM txns WHERE type='transfer' AND affects_balance=1 AND wallet_to_id=? AND id!=? AND timestamp>=?
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
