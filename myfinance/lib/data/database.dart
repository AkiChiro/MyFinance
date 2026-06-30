import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

/// Wallets / bank accounts. `id` is a UUID string so it stays unique across
/// devices — important for safe CSV merge-by-id.
class Wallets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get initialBalance => integer().withDefault(const Constant(0))();
  TextColumn get type => text().withDefault(const Constant('cash'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Transactions ("finance cards"). For a transfer, [walletId] is the source
/// (from) wallet and [walletToId] is the destination (to) wallet.
@DataClassName('Txn')
class Txns extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()(); // spending | earning | transfer
  IntColumn get amount => integer()(); // VND, whole numbers
  TextColumn get description => text().nullable()(); // null for transfer
  TextColumn get walletId => text()(); // from-wallet for transfer
  TextColumn get walletToId => text().nullable()(); // transfer only
  TextColumn get category => text().nullable()(); // null for transfer
  DateTimeColumn get timestamp => dateTime()(); // auto from device, editable
  DateTimeColumn get createdAt => dateTime()();
  // Brought in via CSV merge -> archive-only (excluded from balance & analytics).
  BoolColumn get imported => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Wallets, Txns])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // --- Wallets ---
  Stream<List<Wallet>> watchWallets() =>
      (select(wallets)..orderBy([(w) => OrderingTerm(expression: w.name)]))
          .watch();

  Future<List<Wallet>> allWallets() => select(wallets).get();

  Future<Wallet?> walletById(String id) =>
      (select(wallets)..where((w) => w.id.equals(id))).getSingleOrNull();

  // --- Transactions ---
  Stream<List<Txn>> watchTxns() => (select(txns)
        ..orderBy([
          (t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)
        ]))
      .watch();

  Future<List<Txn>> allTxns() => select(txns).get();

  /// Only the transactions that should affect a live wallet balance:
  /// native (non-imported) entries.
  Future<List<Txn>> nativeTxns() =>
      (select(txns)..where((t) => t.imported.equals(false))).get();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'myfinance.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
