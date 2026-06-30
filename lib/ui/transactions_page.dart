import 'package:flutter/material.dart';

import '../data/database.dart';
import '../format.dart';
import '../main.dart' show repository;
import '../models/domain.dart';
import 'quick_add_page.dart';

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Wallet>>(
      stream: repository.watchWallets(),
      builder: (context, wSnap) {
        final names = {for (final w in (wSnap.data ?? const [])) w.id: w.name};
        return StreamBuilder<List<Txn>>(
          stream: repository.watchTxns(),
          builder: (context, tSnap) {
            final txns = tSnap.data ?? const [];
            if (txns.isEmpty) {
              return const Center(child: Text('Chưa có giao dịch nào.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: txns.length,
              itemBuilder: (context, i) => _TxnTile(
                txn: txns[i],
                walletName: (id) => names[id] ?? '(ví khác)',
              ),
            );
          },
        );
      },
    );
  }
}

class _TxnTile extends StatelessWidget {
  const _TxnTile({required this.txn, required this.walletName});

  final Txn txn;
  final String Function(String id) walletName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSpending = txn.type == TxTypes.spending;
    final isTransfer = txn.type == TxTypes.transfer;

    final (IconData icon, Color color) = switch (txn.type) {
      TxTypes.spending => (Icons.south_west, scheme.error),
      TxTypes.earning => (Icons.north_east, Colors.green.shade700),
      _ => (Icons.swap_horiz, scheme.primary),
    };

    final title = isTransfer
        ? '${walletName(txn.walletId)} → ${walletName(txn.walletToId ?? '')}'
        : (txn.description?.isNotEmpty == true
            ? txn.description!
            : Categories.label(txn.category));

    final subtitleParts = <String>[
      TxTypes.labels[txn.type] ?? txn.type,
      if (!isTransfer) Categories.label(txn.category),
      if (!isTransfer) walletName(txn.walletId),
      formatDateTime(txn.timestamp),
    ];

    final amountText = isTransfer
        ? formatVnd(txn.amount)
        : formatSigned(txn.amount, negative: isSpending);

    return Dismissible(
      key: ValueKey(txn.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: scheme.errorContainer,
        child: Icon(Icons.delete, color: scheme.onErrorContainer),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Xoá giao dịch?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Huỷ')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Xoá')),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => repository.deleteTxn(txn.id),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Row(
          children: [
            Expanded(
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (txn.imported)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _Chip(label: 'đã nhập', scheme: scheme),
              ),
          ],
        ),
        subtitle: Text(subtitleParts.join(' · '),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Text(amountText,
            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        onTap: txn.imported
            ? null // imported rows are archive-only; view but don't edit
            : () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => QuickAddPage(editing: txn),
                )),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.scheme});
  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
