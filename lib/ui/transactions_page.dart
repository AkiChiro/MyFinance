import 'package:flutter/material.dart';

import '../data/database.dart';
import '../format.dart';
import '../main.dart' show repository, settings;
import '../models/domain.dart';
import '../repositories/finance_repository.dart';
import 'quick_add_page.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  bool _starredOnly = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Filter bar ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Tất cả'),
                selected: !_starredOnly,
                onSelected: (_) => setState(() => _starredOnly = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 14),
                    SizedBox(width: 4),
                    Text('Có sao'),
                  ],
                ),
                selected: _starredOnly,
                onSelected: (_) => setState(() => _starredOnly = true),
              ),
            ],
          ),
        ),
        // ── List ─────────────────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<Wallet>>(
            stream: repository.watchWallets(),
            builder: (context, wSnap) {
              final walletMap = {
                for (final w in (wSnap.data ?? const [])) w.id: w.name
              };
              // Load category thresholds for auto-star computation.
              return FutureBuilder<Map<String, int>>(
                future: repository.categoryThresholds(TxTypes.spending),
                builder: (context, threshSnap) {
                  final thresholds = threshSnap.data ?? {};
                  return StreamBuilder<List<Txn>>(
                    stream: repository.watchTxns(),
                    builder: (context, tSnap) {
                      var txns = tSnap.data ?? const [];
                      if (_starredOnly) {
                        txns = txns
                            .where((t) =>
                                t.starred ||
                                isAutoStarred(t, thresholds,
                                    enabled: settings.autostarEnabled))
                            .toList();
                      }
                      if (txns.isEmpty) {
                        return Center(
                          child: Text(_starredOnly
                              ? 'Không có giao dịch nào có sao.'
                              : 'Chưa có giao dịch nào.'),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: txns.length,
                        itemBuilder: (context, i) => _TxnTile(
                          txn: txns[i],
                          thresholds: thresholds,
                          walletName: (id) {
                            if (walletMap.containsKey(id)) {
                              return walletMap[id]!;
                            }
                            return '(ví khác)';
                          },
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _TxnTile extends StatelessWidget {
  const _TxnTile({
    required this.txn,
    required this.walletName,
    required this.thresholds,
  });

  final Txn txn;
  final String Function(String id) walletName;
  final Map<String, int> thresholds;

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

    // Wallet name resolution: live name → snapshot name → fallback.
    String resolveWallet(String? id, String? snapshot) {
      if (id == null || id.isEmpty) return snapshot ?? '(ví khác)';
      final live = walletName(id);
      if (live != '(ví khác)') return live;
      return snapshot ?? '(ví khác)';
    }

    final title = isTransfer
        ? '${resolveWallet(txn.walletId, txn.walletFromName)} → '
            '${resolveWallet(txn.walletToId, txn.walletToName)}'
        : (txn.description?.isNotEmpty == true
            ? txn.description!
            : Categories.label(txn.category));

    final subtitleParts = <String>[
      TxTypes.labels[txn.type] ?? txn.type,
      if (!isTransfer) Categories.label(txn.category),
      if (!isTransfer) resolveWallet(txn.walletId, txn.walletFromName),
      formatDateTime(txn.timestamp),
    ];

    final sym = settings.currencySymbol;
    final suf = settings.currencySuffix;
    final amountText = isTransfer
        ? formatMoney(txn.amount, symbol: sym, suffix: suf)
        : formatSigned(txn.amount,
            negative: isSpending, symbol: sym, suffix: suf);

    final autoStar =
        isAutoStarred(txn, thresholds, enabled: settings.autostarEnabled);
    final showStar = txn.starred || autoStar;

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
            if (showStar)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  txn.starred ? Icons.star : Icons.star_border,
                  size: 16,
                  color: Colors.amber.shade600,
                ),
              ),
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
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => QuickAddPage(editing: txn),
                )),
        onLongPress: () => _showActionSheet(context),
      ),
    );
  }

  void _showActionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!txn.imported) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Sửa'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => QuickAddPage(editing: txn),
                  ));
                },
              ),
              ListTile(
                leading: Icon(
                  txn.starred ? Icons.star : Icons.star_border,
                  color: Colors.amber.shade600,
                ),
                title:
                    Text(txn.starred ? 'Bỏ đánh dấu sao' : 'Đánh dấu sao'),
                onTap: () {
                  Navigator.pop(ctx);
                  repository.toggleStar(txn);
                },
              ),
            ],
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
              title: Text('Xoá',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await showDialog<bool>(
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
                );
                if (ok == true) await repository.deleteTxn(txn.id);
              },
            ),
          ],
        ),
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
