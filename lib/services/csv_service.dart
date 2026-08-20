import 'dart:io';

import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';
import '../models/domain.dart';

/// Result of [CsvService.importAll], reported to the user as e.g.
/// "3 ví mới, 42 giao dịch đã nhập".
class ImportSummary {
  final int walletsAdded;
  final int walletsSkipped;
  final int txnsAdded;
  final int txnsUpdated;
  const ImportSummary({
    required this.walletsAdded,
    required this.walletsSkipped,
    required this.txnsAdded,
    required this.txnsUpdated,
  });
}

const _rtMeta = 'META';
const _rtWallet = 'WALLET';
const _rtTxn = 'TXN';
const _rtCategory = 'CATEGORY';
const _rtSetting = 'SETTING';
const _rtKeyword = 'KEYWORD';
const _rtBudget = 'BUDGET';
const _schemaVersion = '1';

/// Single-file CSV export/import.
///
/// The file has no per-section header row — instead every row's first cell
/// is a record-type discriminator
/// (META/WALLET/TXN/CATEGORY/SETTING/KEYWORD/BUDGET), so heterogeneous
/// "tables" round-trip through one `CsvToListConverter` pass. [importAll]
/// only consumes WALLET and TXN rows; CATEGORY/SETTING/KEYWORD/BUDGET are
/// exported for backup/documentation only.
class CsvService {
  CsvService(this.db);
  final AppDatabase db;

  /// Exports wallets, transactions, categories, app settings, and the
  /// keyword library into a single CSV file for the share sheet.
  ///
  /// [settingsEntries]/[keywordRules] are passed in by the caller (from
  /// `AppSettings.exportEntries()` / `CategorySuggester.loadRaw()`) so this
  /// service only depends on `AppDatabase`, not on the settings/suggester
  /// service classes themselves.
  Future<XFile> exportAll({
    required List<MapEntry<String, String>> settingsEntries,
    required List<Map<String, dynamic>> keywordRules,
  }) async {
    final wallets = await db.allWallets();
    final txns = await db.allTxns();
    final categories = await db.allCategories();
    final budgetHistory = await db.allCategoryBudgetHistory();

    final rows = <List<dynamic>>[
      [_rtMeta, 'schema_version', _schemaVersion],
      [_rtMeta, 'exported_at', DateTime.now().toIso8601String()],
      for (final w in wallets)
        [
          _rtWallet,
          w.id,
          w.name,
          w.initialBalance,
          w.type,
          w.packageName ?? '',
          w.sortOrder,
          w.balanceCutoffAt ?? '',
        ],
      for (final t in txns)
        [
          _rtTxn,
          t.id,
          t.type,
          t.amount,
          t.description ?? '',
          t.walletId,
          t.walletToId ?? '',
          t.walletFromName ?? '',
          t.walletToName ?? '',
          t.category ?? '',
          t.timestamp.toIso8601String(),
          t.imported ? 1 : 0,
          t.starred ? 1 : 0,
          t.source.name,
          t.affectsBalance ? 1 : 0,
        ],
      for (final c in categories)
        [
          _rtCategory,
          c.id,
          c.label,
          c.kind,
          c.threshold,
          c.isDefault ? 1 : 0,
          c.archived ? 1 : 0,
          c.sortOrder,
        ],
      for (final e in settingsEntries) [_rtSetting, e.key, e.value],
      for (final r in keywordRules)
        [_rtKeyword, r['keyword'] ?? '', r['category'] ?? '', r['weight'] ?? 0],
      for (final b in budgetHistory)
        [_rtBudget, b.id, b.categoryId, b.percent, b.effectiveFrom],
    ];

    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File(p.join(dir.path, 'myfinance_backup_$stamp.csv'));
    await file.writeAsString(const ListToCsvConverter().convert(rows));
    return XFile(file.path);
  }

  /// Imports wallets and transactions from a single unified CSV file.
  ///
  /// Wallets: insert-if-absent — a row whose id already exists in the
  /// database is skipped, so live per-wallet state (`balance_cutoff_at`,
  /// `sort_order`, `package_name`) is never clobbered by an older export.
  /// Transactions: upsert by id, applying every column exactly as stored in
  /// the file (no forced mode — `affects_balance`/`source`/`starred` all
  /// round-trip faithfully).
  ///
  /// CATEGORY/SETTING/KEYWORD/META rows are ignored (export-only sections).
  Future<ImportSummary> importAll(String path) async {
    final content = await File(path).readAsString();
    final rows = const CsvToListConverter().convert(content);

    String cell(List<dynamic> r, int i) => i < r.length ? r[i].toString().trim() : '';

    var walletsAdded = 0, walletsSkipped = 0;
    var txnsAdded = 0, txnsUpdated = 0;
    final now = DateTime.now();

    await db.transaction(() async {
      final existingWalletIds = (await db.allWallets()).map((w) => w.id).toSet();
      final existingTxnIds = (await db.allTxns()).map((t) => t.id).toSet();

      for (final r in rows) {
        if (r.isEmpty) continue;
        final recordType = cell(r, 0);

        if (recordType == _rtWallet) {
          final id = cell(r, 1);
          if (id.isEmpty) continue;
          if (existingWalletIds.contains(id)) {
            walletsSkipped++;
            continue;
          }
          final pkg = cell(r, 5);
          final cutoff = cell(r, 7);
          await db.into(db.wallets).insert(WalletsCompanion.insert(
                id: id,
                name: cell(r, 2),
                initialBalance: Value(int.tryParse(cell(r, 3)) ?? 0),
                type: Value(cell(r, 4).isEmpty ? WalletKinds.cash : cell(r, 4)),
                packageName: Value(pkg.isEmpty ? null : pkg),
                sortOrder: Value(int.tryParse(cell(r, 6)) ?? 0),
                balanceCutoffAt: Value(cutoff.isEmpty ? null : int.tryParse(cutoff)),
              ));
          existingWalletIds.add(id);
          walletsAdded++;
        } else if (recordType == _rtTxn) {
          final id = cell(r, 1);
          if (id.isEmpty) continue;
          final desc = cell(r, 4);
          final toId = cell(r, 6);
          final fromName = cell(r, 7);
          final toName = cell(r, 8);
          final cat = cell(r, 9);
          final ts = DateTime.tryParse(cell(r, 10)) ?? now;
          final source = SourceType.values
              .firstWhere((s) => s.name == cell(r, 13), orElse: () => SourceType.csvImport);

          await db.into(db.txns).insertOnConflictUpdate(TxnsCompanion.insert(
                id: id,
                type: cell(r, 2).isEmpty ? TxTypes.spending : cell(r, 2),
                amount: int.tryParse(cell(r, 3)) ?? 0,
                description: Value(desc.isEmpty ? null : desc),
                walletId: cell(r, 5),
                walletToId: Value(toId.isEmpty ? null : toId),
                walletFromName: Value(fromName.isEmpty ? null : fromName),
                walletToName: Value(toName.isEmpty ? null : toName),
                category: Value(cat.isEmpty ? null : cat),
                timestamp: ts,
                createdAt: now,
                imported: Value(cell(r, 11) == '1'),
                starred: Value(cell(r, 12) == '1'),
                source: Value(source),
                affectsBalance: Value(cell(r, 14) == '1'),
              ));
          if (existingTxnIds.add(id)) {
            txnsAdded++;
          } else {
            txnsUpdated++;
          }
        }
        // else: META/CATEGORY/SETTING/KEYWORD — export-only, ignored on import.
      }
    });

    return ImportSummary(
      walletsAdded: walletsAdded,
      walletsSkipped: walletsSkipped,
      txnsAdded: txnsAdded,
      txnsUpdated: txnsUpdated,
    );
  }
}
