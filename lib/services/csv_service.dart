import 'dart:io';

import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';

class ImportResult {
  final int added;
  final int skipped;
  const ImportResult(this.added, this.skipped);
}

class CsvService {
  CsvService(this.db);
  final AppDatabase db;

  /// Writes two CSVs (transactions + wallets) to a temp dir and returns them
  /// for the share sheet. Fully offline — sharing/saving is the user's choice.
  Future<List<XFile>> export() async {
    final txList = await db.allTxns();
    final wList = await db.allWallets();

    final txRows = <List<dynamic>>[
      [
        'id', 'type', 'amount', 'description',
        'wallet_id', 'wallet_to_id', 'category', 'timestamp', 'imported'
      ],
      for (final t in txList)
        [
          t.id, t.type, t.amount, t.description ?? '',
          t.walletId, t.walletToId ?? '', t.category ?? '',
          t.timestamp.toIso8601String(), t.imported ? 1 : 0,
        ],
    ];

    final wRows = <List<dynamic>>[
      ['id', 'name', 'initial_balance', 'type'],
      for (final w in wList) [w.id, w.name, w.initialBalance, w.type],
    ];

    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final txFile = File(p.join(dir.path, 'myfinance_txns_$stamp.csv'));
    final wFile = File(p.join(dir.path, 'myfinance_wallets_$stamp.csv'));

    await txFile.writeAsString(const ListToCsvConverter().convert(txRows));
    await wFile.writeAsString(const ListToCsvConverter().convert(wRows));

    return [XFile(txFile.path), XFile(wFile.path)];
  }

  /// Merge-by-id import of a transactions CSV. Rows whose id already exists are
  /// skipped; new rows are inserted and flagged `imported` (archive-only:
  /// excluded from balance and analytics).
  Future<ImportResult> importMerge(String path) async {
    final content = await File(path).readAsString();
    final rows = const CsvToListConverter().convert(content);
    if (rows.length < 2) return const ImportResult(0, 0);

    final header = rows.first.map((e) => e.toString().trim()).toList();
    final idx = {for (var i = 0; i < header.length; i++) header[i]: i};

    String cell(List<dynamic> r, String key) {
      final i = idx[key];
      if (i == null || i >= r.length) return '';
      return r[i].toString().trim();
    }

    final existing = (await db.allTxns()).map((t) => t.id).toSet();
    final now = DateTime.now();
    var added = 0, skipped = 0;

    for (final r in rows.skip(1)) {
      final id = cell(r, 'id');
      if (id.isEmpty || existing.contains(id)) {
        skipped++;
        continue;
      }
      final type = cell(r, 'type');
      final amount = int.tryParse(cell(r, 'amount')) ?? 0;
      final ts = DateTime.tryParse(cell(r, 'timestamp')) ?? now;
      final desc = cell(r, 'description');
      final toId = cell(r, 'wallet_to_id');
      final cat = cell(r, 'category');

      await db.into(db.txns).insert(TxnsCompanion.insert(
            id: id,
            type: type.isEmpty ? 'spending' : type,
            amount: amount,
            description: Value(desc.isEmpty ? null : desc),
            walletId: cell(r, 'wallet_id'),
            walletToId: Value(toId.isEmpty ? null : toId),
            category: Value(cat.isEmpty ? null : cat),
            timestamp: ts,
            createdAt: now,
            imported: const Value(true), // archive-only on this device
          ));
      existing.add(id);
      added++;
    }
    return ImportResult(added, skipped);
  }
}
