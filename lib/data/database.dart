import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

// ── Tables ────────────────────────────────────────────────────────────────────

class Wallets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get initialBalance => integer().withDefault(const Constant(0))();
  TextColumn get type => text().withDefault(const Constant('cash'))();

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

// ── Database ──────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [Wallets, Txns, AppCategories])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

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

  Stream<List<Wallet>> watchWallets() =>
      (select(wallets)..orderBy([(w) => OrderingTerm(expression: w.name)]))
          .watch();

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
      (select(txns)..where((t) => t.imported.equals(false))).get();

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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'myfinance.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
