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

  /// Exports two CSVs (transactions + wallets) and returns them for the share
  /// sheet. Now includes wallet_from_name and wallet_to_name snapshot columns
  /// so that a restore can recover readable wallet names even if wallets change.
  Future<List<XFile>> export() async {
    final txList = await db.allTxns();
    final wList = await db.allWallets();

    final txRows = <List<dynamic>>[
      [
        'id', 'type', 'amount', 'description',
        'wallet_id', 'wallet_to_id',
        'wallet_from_name', 'wallet_to_name',
        'category', 'timestamp', 'imported', 'starred',
      ],
      for (final t in txList)
        [
          t.id, t.type, t.amount, t.description ?? '',
          t.walletId, t.walletToId ?? '',
          t.walletFromName ?? '', t.walletToName ?? '',
          t.category ?? '',
          t.timestamp.toIso8601String(),
          t.imported ? 1 : 0,
          t.starred ? 1 : 0,
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

  /// Merge-by-id import of a transactions CSV. Rows whose id already exists
  /// are skipped. New rows are flagged `imported` (archive-only: excluded from
  /// balance and analytics). Reads wallet name snapshot columns when present.
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
      final fromName = cell(r, 'wallet_from_name');
      final toName = cell(r, 'wallet_to_name');

      await db.into(db.txns).insert(TxnsCompanion.insert(
            id: id,
            type: type.isEmpty ? 'spending' : type,
            amount: amount,
            description: Value(desc.isEmpty ? null : desc),
            walletId: cell(r, 'wallet_id'),
            walletToId: Value(toId.isEmpty ? null : toId),
            walletFromName: Value(fromName.isEmpty ? null : fromName),
            walletToName: Value(toName.isEmpty ? null : toName),
            category: Value(cat.isEmpty ? null : cat),
            timestamp: ts,
            createdAt: now,
            imported: const Value(true),
          ));
      existing.add(id);
      added++;
    }
    return ImportResult(added, skipped);
  }

  /// Full restore: delete all local data then insert wallets + transactions
  /// from the given CSV paths. Transactions are NOT flagged as imported —
  /// they restore full balance/analytics participation.
  Future<ImportResult> importReplace(
      String walletsPath, String txnsPath) async {
    await db.delete(db.txns).go();
    await db.delete(db.wallets).go();

    // ── Wallets ──────────────────────────────────────────────────────────────
    final wContent = await File(walletsPath).readAsString();
    final wRows = const CsvToListConverter().convert(wContent);
    if (wRows.length >= 2) {
      final wHeader = wRows.first.map((e) => e.toString().trim()).toList();
      final wIdx = {for (var i = 0; i < wHeader.length; i++) wHeader[i]: i};
      String wcell(List<dynamic> r, String key) {
        final i = wIdx[key];
        if (i == null || i >= r.length) return '';
        return r[i].toString().trim();
      }

      for (final r in wRows.skip(1)) {
        final id = wcell(r, 'id');
        if (id.isEmpty) continue;
        await db.into(db.wallets).insertOnConflictUpdate(WalletsCompanion(
          id: Value(id),
          name: Value(wcell(r, 'name')),
          initialBalance: Value(int.tryParse(wcell(r, 'initial_balance')) ?? 0),
          type: Value(wcell(r, 'type')),
        ));
      }
    }

    // ── Transactions ─────────────────────────────────────────────────────────
    final tContent = await File(txnsPath).readAsString();
    final tRows = const CsvToListConverter().convert(tContent);
    if (tRows.length < 2) return const ImportResult(0, 0);

    final tHeader = tRows.first.map((e) => e.toString().trim()).toList();
    final tIdx = {for (var i = 0; i < tHeader.length; i++) tHeader[i]: i};
    String tcell(List<dynamic> r, String key) {
      final i = tIdx[key];
      if (i == null || i >= r.length) return '';
      return r[i].toString().trim();
    }

    final now = DateTime.now();
    var added = 0;
    for (final r in tRows.skip(1)) {
      final id = tcell(r, 'id');
      if (id.isEmpty) continue;
      final type = tcell(r, 'type');
      final amount = int.tryParse(tcell(r, 'amount')) ?? 0;
      final ts = DateTime.tryParse(tcell(r, 'timestamp')) ?? now;
      final desc = tcell(r, 'description');
      final toId = tcell(r, 'wallet_to_id');
      final cat = tcell(r, 'category');
      final fromName = tcell(r, 'wallet_from_name');
      final toName = tcell(r, 'wallet_to_name');
      final starred = tcell(r, 'starred') == '1';

      await db.into(db.txns).insertOnConflictUpdate(TxnsCompanion.insert(
            id: id,
            type: type.isEmpty ? 'spending' : type,
            amount: amount,
            description: Value(desc.isEmpty ? null : desc),
            walletId: tcell(r, 'wallet_id'),
            walletToId: Value(toId.isEmpty ? null : toId),
            walletFromName: Value(fromName.isEmpty ? null : fromName),
            walletToName: Value(toName.isEmpty ? null : toName),
            category: Value(cat.isEmpty ? null : cat),
            starred: Value(starred),
            timestamp: ts,
            createdAt: now,
          ));
      added++;
    }
    return ImportResult(added, 0);
  }
}
