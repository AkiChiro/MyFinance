import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../models/domain.dart';
import 'csv_service.dart';

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

  // ---------- streams ----------
  Stream<List<Wallet>> watchWallets() => db.watchWallets();
  Stream<List<Txn>> watchTxns() => db.watchTxns();
  Future<List<Wallet>> allWallets() => db.allWallets();

  // ---------- balance ----------
  /// Pure balance computation over a given transaction list (UI-friendly).
  /// Imported (archive-only) transactions never affect the balance.
  int balanceOf(Wallet w, List<Txn> txns) {
    var bal = w.initialBalance;
    for (final t in txns) {
      if (t.imported) continue;
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

  Future<int> _balance(String walletId, {String? excludeId}) async {
    final w = await db.walletById(walletId);
    if (w == null) return 0;
    final txns = await db.nativeTxns();
    return balanceOf(w, [
      for (final t in txns)
        if (t.id != excludeId) t
    ]);
  }

  Future<void> _assertSufficient(String walletId, int amount,
      {String? excludeId}) async {
    final available = await _balance(walletId, excludeId: excludeId);
    if (amount > available) throw const OverspendException();
  }

  // ---------- wallets ----------
  Future<void> addWallet({
    required String name,
    required int initialBalance,
    String type = WalletKinds.cash,
  }) {
    return db.into(db.wallets).insert(WalletsCompanion.insert(
          id: _uuid.v4(),
          name: name,
          initialBalance: Value(initialBalance),
          type: Value(type),
        ));
  }

  Future<void> deleteWallet(String id) =>
      (db.delete(db.wallets)..where((w) => w.id.equals(id))).go();

  // ---------- create transactions ----------
  Future<void> addSpending({
    required int amount,
    required String walletId,
    required String category,
    String? description,
    DateTime? timestamp,
  }) async {
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
  }

  // ---------- edit / delete ----------
  /// Replaces an existing transaction. Re-runs the overspend guard (excluding
  /// the row being edited) for spending/transfer.
  Future<void> updateTxn(Txn t) async {
    if (t.type == TxTypes.spending || t.type == TxTypes.transfer) {
      await _assertSufficient(t.walletId, t.amount, excludeId: t.id);
    }
    await db.update(db.txns).replace(t);
  }

  Future<void> deleteTxn(String id) =>
      (db.delete(db.txns)..where((t) => t.id.equals(id))).go();
}
