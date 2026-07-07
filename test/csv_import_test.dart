import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfinance/data/database.dart';
import 'package:myfinance/models/domain.dart';
import 'package:myfinance/repositories/finance_repository.dart';
import 'package:myfinance/services/csv_service.dart';

const _kCsvHeader =
    'id,type,amount,description,wallet_id,wallet_to_id,'
    'wallet_from_name,wallet_to_name,category,timestamp,imported,starred';

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

  File writeCsv(String content) {
    final f = File('${tempDir.path}/import.csv');
    f.writeAsStringSync(content);
    return f;
  }

  group('importMerge', () {
    test('context-only: rows get affectsBalance=false and balance is unchanged',
        () async {
      await repo.addWallet(name: 'Cash', initialBalance: 500000);
      final wallet = (await db.allWallets()).first;

      final f = writeCsv('$_kCsvHeader\r\n'
          'csv1,spending,100000,,${wallet.id},,,,,2024-01-01T00:00:00.000,0,0\r\n');

      final result =
          await csv.importMerge(f.path, mode: CsvImportMode.contextOnly);

      expect(result.added, 1);
      final txns = await db.allTxns();
      expect(txns.length, 1);
      expect(txns.first.source, SourceType.csvImport);
      expect(txns.first.affectsBalance, isFalse,
          reason: 'context-only rows must not affect balance');
      expect(txns.first.imported, isTrue);

      // Balance unchanged — context-only row is excluded
      expect(repo.balanceOf(wallet, txns), 500000);
    });

    test('reconstruct-balance: rows get affectsBalance=true and balance reflects imports',
        () async {
      await repo.addWallet(name: 'Fresh', initialBalance: 0);
      final wallet = (await db.allWallets()).first;

      final f = writeCsv('$_kCsvHeader\r\n'
          'csv1,earning,300000,,${wallet.id},,,,,2024-01-01T00:00:00.000,0,0\r\n'
          'csv2,spending,50000,,${wallet.id},,,,,2024-01-02T00:00:00.000,0,0\r\n');

      await csv.importMerge(f.path, mode: CsvImportMode.reconstructBalance);

      final txns = await db.allTxns();
      expect(txns.length, 2);
      expect(txns.every((t) => t.affectsBalance), isTrue,
          reason: 'reconstruct-balance rows must affect balance');
      expect(txns.every((t) => t.source == SourceType.csvImport), isTrue);

      // balance = 0 (initial) + 300000 (earning) - 50000 (spending) = 250000
      expect(repo.balanceOf(wallet, txns), 250000);
    });

    test('reconstruct-balance: throws NonEmptyWalletReconstructError for non-empty wallet',
        () async {
      await repo.addWallet(name: 'Existing', initialBalance: 200000);
      final wallet = (await db.allWallets()).first;

      // Add a native (affectsBalance=true) transaction
      await repo.addSpending(
        walletId: wallet.id,
        amount: 50000,
        category: 'food',
        timestamp: DateTime(2024),
      );

      final f = writeCsv('$_kCsvHeader\r\n'
          'csv_new,spending,10000,,${wallet.id},,,,,2024-01-01T00:00:00.000,0,0\r\n');

      await expectLater(
        csv.importMerge(f.path, mode: CsvImportMode.reconstructBalance),
        throwsA(isA<NonEmptyWalletReconstructError>()),
      );
    });
  });
}
