import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../models/domain.dart';
import '../services/csv_service.dart';

const _uuid = Uuid();

/// Thrown when a spending or transfer would push a wallet below zero.
class OverspendException implements Exception {
  final String message;
  const OverspendException([this.message = 'Hãy kiểm tra lại số tiền thực tế']);
  @override
  String toString() => message;
}

class FinanceRepository {
  FinanceRepository(this.db) : csv = CsvService(db);

  final AppDatabase db;
  final CsvService csv;

  // ── Streams ─────────────────────────────────────────────────────────────────

  Stream<List<Wallet>> watchWallets() => db.watchWallets();
  Stream<List<Txn>> watchTxns() => db.watchTxns();
  Stream<Map<String, int>> watchWalletBalances() => db.watchWalletBalances();
  Stream<AnalyticsBundle> watchAnalyticsBundle(DateTime month) =>
      db.watchAnalyticsBundle(month);
  Stream<List<NotificationCapture>> watchPendingCaptures() =>
      db.watchPendingCaptures();
  Stream<int> pendingCaptureCount() => db.pendingCaptureCount();
  Future<List<Wallet>> allWallets() => db.allWallets();

  // ── Categories ────────────────────────────────────────────────────────────────

  Stream<List<AppCategory>> watchActiveCategories(String kind) =>
      db.watchActiveCategories(kind);

  Future<List<AppCategory>> activeCategories(String kind) =>
      db.activeCategories(kind);

  Future<Map<String, int>> categoryThresholds(String kind) =>
      db.categoryThresholds(kind);

  Future<void> addCategory({
    required String label,
    required String kind,
    int threshold = 0,
  }) async {
    final existing = await db.activeCategories(kind);
    await db.into(db.appCategories).insert(
          AppCategoriesCompanion.insert(
            id: _uuid.v4(),
            label: label,
            kind: kind,
            threshold: Value(threshold),
            sortOrder: Value(existing.length),
          ),
        );
  }

  Future<void> updateCategory(AppCategory cat) =>
      db.update(db.appCategories).replace(cat);

  Future<List<AppCategory>> allActiveCategories() => db.allActiveCategories();

  // No archived filter — used to build label maps for rendering historical txns.
  Stream<List<AppCategory>> watchAllCategories() => db.watchAllCategories();
  Future<List<AppCategory>> allCategories() => db.allCategories();

  Future<void> archiveCategory(String id) =>
      (db.update(db.appCategories)..where((c) => c.id.equals(id)))
          .write(const AppCategoriesCompanion(archived: Value(true)));

  Future<void> unarchiveCategory(String id) =>
      (db.update(db.appCategories)..where((c) => c.id.equals(id)))
          .write(const AppCategoriesCompanion(archived: Value(false)));

  Future<void> setCategoryThreshold(String id, int threshold) =>
      (db.update(db.appCategories)..where((c) => c.id.equals(id)))
          .write(AppCategoriesCompanion(threshold: Value(threshold)));

  // ── Balance ─────────────────────────────────────────────────────────────────

  @visibleForTesting
  int balanceOf(Wallet w, List<Txn> txns) {
    var bal = w.initialBalance;
    for (final t in txns) {
      if (!t.affectsBalance) continue;
      switch (t.type) {
        case TxTypes.spending:
          if (t.walletId == w.id) bal -= t.amount;
          break;
        case TxTypes.earning:
          if (t.walletId == w.id) bal += t.amount;
          break;
        case TxTypes.transfer:
          if (t.walletId == w.id) bal -= t.amount;
          if (t.walletToId == w.id) bal += t.amount;
          break;
      }
    }
    return bal;
  }

  Future<int> _balance(String walletId, {String? excludeId}) =>
      db.sqlBalance(walletId, excludeId: excludeId);

  Future<void> _assertSufficient(String walletId, int amount,
      {String? excludeId}) async {
    final available = await _balance(walletId, excludeId: excludeId);
    if (amount > available) throw const OverspendException();
  }

  // ── Wallets ──────────────────────────────────────────────────────────────────

  Future<String> addWallet({
    required String name,
    required int initialBalance,
    String type = WalletKinds.cash,
    String? packageName,
  }) async {
    final id = _uuid.v4();
    await db.into(db.wallets).insert(WalletsCompanion.insert(
          id: id,
          name: name,
          initialBalance: Value(initialBalance),
          type: Value(type),
          packageName: Value(packageName),
        ));
    return id;
  }

  /// Atomically clears [packageName] from whichever wallet currently holds it
  /// and assigns it to [newWalletId]. Safe to call when no wallet currently
  /// holds the package (the first UPDATE is a no-op).
  Future<void> reassignWalletBankLink(
      String packageName, String newWalletId) =>
      db.transaction(() async {
        await (db.update(db.wallets)
              ..where((w) => w.packageName.equals(packageName)))
            .write(const WalletsCompanion(packageName: Value(null)));
        await (db.update(db.wallets)..where((w) => w.id.equals(newWalletId)))
            .write(WalletsCompanion(packageName: Value(packageName)));
      });

  /// Updates only the [packageName] column for wallet [id].
  /// Pass null to unlink any associated bank app.
  Future<void> updateWalletPackageName(String id, String? packageName) =>
      (db.update(db.wallets)..where((w) => w.id.equals(id)))
          .write(WalletsCompanion(packageName: Value(packageName)));

  Future<Wallet?> walletByPackageName(String pkg) =>
      db.walletByPackageName(pkg);

  Future<void> deleteWallet(String id) =>
      (db.delete(db.wallets)..where((w) => w.id.equals(id))).go();

  // ── Create transactions ──────────────────────────────────────────────────────

  Future<void> addSpending({
    required int amount,
    required String walletId,
    required String category,
    String? description,
    DateTime? timestamp,
  }) async {
    await db.transaction(() async {
      await _assertSufficient(walletId, amount);
      final now = DateTime.now();
      await db.into(db.txns).insert(TxnsCompanion.insert(
            id: _uuid.v4(),
            type: TxTypes.spending,
            amount: amount,
            description: Value(description),
            walletId: walletId,
            category: Value(category),
            timestamp: timestamp ?? now,
            createdAt: now,
          ));
    });
  }

  Future<void> addEarning({
    required int amount,
    required String walletId,
    required String category,
    String? description,
    DateTime? timestamp,
  }) async {
    final now = DateTime.now();
    await db.into(db.txns).insert(TxnsCompanion.insert(
          id: _uuid.v4(),
          type: TxTypes.earning,
          amount: amount,
          description: Value(description),
          walletId: walletId,
          category: Value(category),
          timestamp: timestamp ?? now,
          createdAt: now,
        ));
  }

  Future<void> addTransfer({
    required int amount,
    required String fromWalletId,
    required String toWalletId,
    DateTime? timestamp,
  }) async {
    await db.transaction(() async {
      await _assertSufficient(fromWalletId, amount);
      final now = DateTime.now();
      await db.into(db.txns).insert(TxnsCompanion.insert(
            id: _uuid.v4(),
            type: TxTypes.transfer,
            amount: amount,
            walletId: fromWalletId,
            walletToId: Value(toWalletId),
            timestamp: timestamp ?? now,
            createdAt: now,
          ));
    });
  }

  // ── Edit / delete ────────────────────────────────────────────────────────────

  Future<void> updateTxn(Txn t) async {
    await db.transaction(() async {
      if (t.type == TxTypes.spending || t.type == TxTypes.transfer) {
        await _assertSufficient(t.walletId, t.amount, excludeId: t.id);
      }
      await db.update(db.txns).replace(t);
    });
  }

  Future<void> deleteTxn(String id) =>
      (db.delete(db.txns)..where((t) => t.id.equals(id))).go();

  // ── Starred (§5) ─────────────────────────────────────────────────────────────

  Future<void> setStarred(String id, {required bool starred}) =>
      (db.update(db.txns)..where((t) => t.id.equals(id)))
          .write(TxnsCompanion(starred: Value(starred)));

  Future<void> toggleStar(Txn txn) =>
      setStarred(txn.id, starred: !txn.starred);

  // ── Bank-notification captures ────────────────────────────────────────────────

  /// Normalizes notification text for dedup comparison:
  /// trim + collapse internal whitespace + lowercase.
  static String _normalizeText(String text) =>
      text.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  /// Composite dedup key: packageName + ASCII-RS separator + normalized text.
  /// Not a hash — stores the full string so dedup is a plain equality check.
  static String _dedupKey(String packageName, String rawText) =>
      '$packageName\x1e${_normalizeText(rawText)}';

  /// Inserts a notification capture with dedup and wallet-resolution.
  ///
  /// Returns the inserted [NotificationCapture], or `null` if an equivalent
  /// capture already exists within a 2-minute window (dedup skip).
  Future<NotificationCapture?> insertCapture({
    required String packageName,
    String? rawTitle,
    required String rawText,
    required DateTime capturedAt,
    int? amount,
    CaptureDirection? direction,
    ParseStatus parseStatus = ParseStatus.unparsed,
  }) async {
    final key = _dedupKey(packageName, rawText);
    final windowStart = capturedAt.subtract(const Duration(minutes: 2));

    final duplicate = await (db.select(db.notificationCaptures)
          ..where((c) =>
              c.dedupKey.equals(key) &
              c.capturedAt.isBiggerOrEqualValue(windowStart)))
        .getSingleOrNull();
    if (duplicate != null) return null;

    // Resolve default wallet from package association (ADR-0014).
    final wallet = await db.walletByPackageName(packageName);

    final id = _uuid.v4();
    await db.into(db.notificationCaptures).insert(
          NotificationCapturesCompanion.insert(
            id: id,
            packageName: packageName,
            rawTitle: Value(rawTitle),
            rawText: rawText,
            capturedAt: capturedAt,
            amount: Value(amount),
            direction: Value(direction),
            parseStatus: Value(parseStatus),
            suggestedWalletId: Value(wallet?.id),
            dedupKey: key,
          ),
        );
    return (db.select(db.notificationCaptures)
          ..where((c) => c.id.equals(id)))
        .getSingle();
  }

  /// Atomically creates a transaction from a capture and marks it confirmed.
  ///
  /// Bypasses [_assertSufficient] intentionally: bank notifications record money
  /// that already moved, so tracking an expense that makes the balance negative
  /// is correct. The passed-in values override the stored proposal (user may
  /// have edited them at confirm time).
  ///
  /// [timestamp] is the moment the money moved. Defaults to the capture's own
  /// [capturedAt] (when the bank notification arrived) so analytics attribute
  /// the transaction to the correct day — not to whenever the user reviewed the
  /// inbox. Pass an explicit value when the user edits the date on the confirm
  /// screen.
  Future<void> confirmCapture(
    String captureId, {
    required String walletId,
    required int amount,
    required CaptureDirection direction,
    String? category,
    bool starred = false,
    DateTime? timestamp,
  }) async {
    final txnId = _uuid.v4();
    final type =
        direction == CaptureDirection.income ? TxTypes.earning : TxTypes.spending;

    await db.transaction(() async {
      // Resolve timestamp: use the caller-supplied value, or fall back to the
      // capture's capturedAt so the transaction lands on the correct day.
      final txnTimestamp = timestamp ??
          (await (db.select(db.notificationCaptures)
                    ..where((c) => c.id.equals(captureId)))
                .getSingleOrNull())
              ?.capturedAt ??
          DateTime.now();

      await db.into(db.txns).insert(TxnsCompanion.insert(
            id: txnId,
            type: type,
            amount: amount,
            walletId: walletId,
            category: Value(category),
            timestamp: txnTimestamp,
            createdAt: DateTime.now(),
            imported: const Value(false),
            source: const Value(SourceType.bankNotification),
            affectsBalance: const Value(true),
            starred: Value(starred),
          ));
      await (db.update(db.notificationCaptures)
            ..where((c) => c.id.equals(captureId)))
          .write(NotificationCapturesCompanion(
            status: const Value(CaptureStatus.confirmed),
            resultingTxnId: Value(txnId),
          ));
    });
  }

  /// Marks a capture as dismissed. No transaction is created.
  Future<void> dismissCapture(String captureId) =>
      (db.update(db.notificationCaptures)
            ..where((c) => c.id.equals(captureId)))
          .write(const NotificationCapturesCompanion(
            status: Value(CaptureStatus.dismissed),
          ));

}

// ── Auto-star helper (§5) — pure function, no repository needed ───────────────

/// Returns true if [t] should be auto-starred based on category thresholds.
/// [thresholds] is a Map<categoryId, VND limit> from the Categories table.
bool isAutoStarred(
  Txn t,
  Map<String, int> thresholds, {
  required bool enabled,
}) {
  if (!enabled) return false;
  if (t.type != TxTypes.spending || t.imported || t.walletToId != null) {
    return false;
  }
  final limit = thresholds[t.category] ?? 0;
  return limit > 0 && t.amount > limit;
}
