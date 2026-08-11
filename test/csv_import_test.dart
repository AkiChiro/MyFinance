import 'dart:io';

import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfinance/data/database.dart';
import 'package:myfinance/repositories/finance_repository.dart';
import 'package:myfinance/services/csv_service.dart';

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late FinanceRepository repo;
  late CsvService csv;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('csv_import_test_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FinanceRepository(db);
    csv = CsvService(db);
  });

  tearDown(() async {
    await db.close();
    tempDir.deleteSync(recursive: true);
  });

  File writeCsv(List<List<dynamic>> rows) {
    final f = File('${tempDir.path}/import.csv');
    f.writeAsStringSync(const ListToCsvConverter().convert(rows));
    return f;
  }

  List<dynamic> walletRow(String id, String name, int initialBalance) =>
      ['WALLET', id, name, initialBalance, 'cash', '', 0, ''];

  List<dynamic> txnRow(
    String id, {
    required String type,
    required int amount,
    required String walletId,
    String description = '',
    String timestamp = '2024-01-01T00:00:00.000',
    bool affectsBalance = true,
  }) =>
      [
        'TXN', id, type, amount, description, walletId, '', '', '', '',
        timestamp, 0, 0, 'csvImport', affectsBalance ? 1 : 0,
      ];

  group('importAll', () {
    test('imports wallets and transactions into an empty database', () async {
      final f = writeCsv([
        walletRow('w1', 'Cash', 500000),
        txnRow('t1', type: 'earning', amount: 300000, walletId: 'w1'),
        txnRow('t2', type: 'spending', amount: 50000, walletId: 'w1',
            timestamp: '2024-01-02T00:00:00.000'),
      ]);

      final result = await csv.importAll(f.path);

      expect(result.walletsAdded, 1);
      expect(result.walletsSkipped, 0);
      expect(result.txnsAdded, 2);
      expect(result.txnsUpdated, 0);

      final wallet = (await db.allWallets()).single;
      expect(wallet.name, 'Cash');
      expect(wallet.initialBalance, 500000);

      final txns = await db.allTxns();
      expect(txns.length, 2);
      expect(repo.balanceOf(wallet, txns), 750000);
    });

    test('re-importing the same file is idempotent', () async {
      final f = writeCsv([
        walletRow('w1', 'Cash', 500000),
        txnRow('t1', type: 'earning', amount: 300000, walletId: 'w1'),
      ]);

      await csv.importAll(f.path);
      final result2 = await csv.importAll(f.path);

      expect(result2.walletsAdded, 0);
      expect(result2.walletsSkipped, 1);
      expect(result2.txnsAdded, 0);
      expect(result2.txnsUpdated, 1);

      expect((await db.allWallets()).length, 1);
      expect((await db.allTxns()).length, 1);
    });

    test('existing wallet with a matching id is preserved, not overwritten',
        () async {
      await db.into(db.wallets).insert(WalletsCompanion.insert(
            id: 'w-fixed',
            name: 'Original',
            initialBalance: const Value(100),
          ));

      final f = writeCsv([walletRow('w-fixed', 'Imported', 999999)]);
      final result = await csv.importAll(f.path);

      expect(result.walletsAdded, 0);
      expect(result.walletsSkipped, 1);
      final wallet = await db.walletById('w-fixed');
      expect(wallet!.name, 'Original');
      expect(wallet.initialBalance, 100);
    });

    test('existing transaction with a matching id is updated from the CSV',
        () async {
      await db.into(db.wallets).insert(WalletsCompanion.insert(
            id: 'w1',
            name: 'Cash',
            initialBalance: const Value(0),
          ));
      await db.into(db.txns).insert(TxnsCompanion.insert(
            id: 't-fixed',
            type: 'spending',
            amount: 100,
            walletId: 'w1',
            timestamp: DateTime(2024),
            createdAt: DateTime(2024),
            description: const Value('old'),
          ));

      final f = writeCsv([
        txnRow('t-fixed',
            type: 'spending', amount: 200000, walletId: 'w1',
            description: 'updated'),
      ]);
      final result = await csv.importAll(f.path);

      expect(result.txnsAdded, 0);
      expect(result.txnsUpdated, 1);
      final txn = (await db.allTxns()).single;
      expect(txn.amount, 200000);
      expect(txn.description, 'updated');
    });

    test('CATEGORY/SETTING/KEYWORD/META rows are ignored without error',
        () async {
      final f = writeCsv([
        ['META', 'schema_version', '1'],
        ['CATEGORY', 'fake', 'Fake', 'spending', 0, 0, 0, 0],
        ['SETTING', 'ui.locale', 'vi'],
        ['KEYWORD', 'cà phê', 'food', 10],
      ]);

      final result = await csv.importAll(f.path);

      expect(result.walletsAdded, 0);
      expect(result.txnsAdded, 0);
      expect(await db.allWallets(), isEmpty);
      expect(await db.allTxns(), isEmpty);
      // The fake CSV category row must not have been written to the DB.
      final categories = await db.allCategories();
      expect(categories.any((c) => c.id == 'fake'), isFalse);
    });
  });
}
