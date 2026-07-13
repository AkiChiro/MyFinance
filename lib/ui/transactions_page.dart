import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../format.dart';
import '../models/domain.dart';
import '../providers.dart';
import '../repositories/finance_repository.dart';
import 'captures_page.dart';
import 'quick_add_page.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  bool _starredOnly = false;
  String? _typeFilter; // null = all, TxTypes.spending, TxTypes.earning
  String? _categoryFilter;
  bool _sortByAmount = false;

  Widget _buildFilterBar(
      BuildContext context, List<AppCategory> allCats, Map<String, String> catLabels) {
    final typeCats = _typeFilter == null
        ? const <AppCategory>[]
        : allCats.where((c) => c.kind == _typeFilter && !c.archived).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Tất cả'),
            selected: _typeFilter == null,
            onSelected: (_) => setState(() {
              _typeFilter = null;
              _categoryFilter = null;
            }),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Chi tiêu'),
            selected: _typeFilter == TxTypes.spending,
            onSelected: (_) => setState(() {
              _typeFilter = TxTypes.spending;
              _categoryFilter = null;
            }),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Thu nhập'),
            selected: _typeFilter == TxTypes.earning,
            onSelected: (_) => setState(() {
              _typeFilter = TxTypes.earning;
              _categoryFilter = null;
            }),
          ),
          const SizedBox(width: 8),
          FilterChip(
            avatar: Icon(Icons.star,
                size: 14,
                color: _starredOnly ? Colors.amber.shade700 : null),
            label: const Text('Có sao'),
            selected: _starredOnly,
            onSelected: (v) => setState(() => _starredOnly = v),
          ),
          if (_typeFilter != null) ...[
            const SizedBox(width: 8),
            FilterChip(
              label: Text(_categoryFilter == null
                  ? 'Danh mục'
                  : (catLabels[_categoryFilter] ?? _categoryFilter!)),
              selected: _categoryFilter != null,
              onSelected: (_) => _pickCategory(context, typeCats),
            ),
          ],
          const SizedBox(width: 8),
          FilterChip(
            avatar: const Icon(Icons.sort, size: 14),
            label: const Text('Số tiền'),
            selected: _sortByAmount,
            onSelected: (v) => setState(() => _sortByAmount = v),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCategory(
      BuildContext context, List<AppCategory> cats) async {
    // Use a list wrapper so we can distinguish "dismissed" (null) from
    // "all selected" ([null]) and "category selected" ([id]).
    final picked = await showDialog<List<String?>>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Chọn danh mục'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, [null]),
            child: const Text('Tất cả'),
          ),
          for (final c in cats)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, [c.id]),
              child: Text(c.label),
            ),
        ],
      ),
    );
    if (picked != null && mounted) {
      setState(() => _categoryFilter = picked[0]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repositoryProvider);
    final settings = ref.watch(settingsProvider);

    return StreamBuilder<List<AppCategory>>(
      stream: repo.watchAllCategories(),
      builder: (context, catSnap) {
        final allCats = catSnap.data ?? const <AppCategory>[];
        final catLabels = {for (final c in allCats) c.id: c.label};

        return Column(
          children: [
            // ── Filter bar ──────────────────────────────────────────────────
            _buildFilterBar(context, allCats, catLabels),
            // ── Captures banner ─────────────────────────────────────────────
            StreamBuilder<int>(
              stream: repo.pendingCaptureCount(),
              builder: (context, snap) {
                final count = snap.data ?? 0;
                if (count == 0) return const SizedBox.shrink();
                final scheme = Theme.of(context).colorScheme;
                return Card(
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  color: scheme.primaryContainer,
                  child: ListTile(
                    leading: Badge(
                      label: Text('$count'),
                      child: Icon(Icons.notifications_outlined,
                          color: scheme.onPrimaryContainer),
                    ),
                    title: Text(
                      '$count thông báo ngân hàng chờ xác nhận',
                      style: TextStyle(color: scheme.onPrimaryContainer),
                    ),
                    trailing: Icon(Icons.chevron_right,
                        color: scheme.onPrimaryContainer),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CapturesPage()),
                    ),
                  ),
                );
              },
            ),
            // ── List ────────────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<List<Wallet>>(
                stream: repo.watchWallets(),
                builder: (context, wSnap) {
                  final walletMap = {
                    for (final w in (wSnap.data ?? const [])) w.id: w.name
                  };
                  return FutureBuilder<Map<String, int>>(
                    future: repo.categoryThresholds(TxTypes.spending),
                    builder: (context, threshSnap) {
                      final thresholds = threshSnap.data ?? {};
                      return StreamBuilder<List<Txn>>(
                        stream: repo.watchTxns(),
                        builder: (context, tSnap) {
                          var txns = tSnap.data ?? const [];
                          // Apply filters.
                          if (_starredOnly) {
                            txns = txns
                                .where((t) =>
                                    t.starred ||
                                    isAutoStarred(t, thresholds,
                                        enabled: settings.autostarEnabled))
                                .toList();
                          }
                          if (_typeFilter != null) {
                            txns = txns
                                .where((t) => t.type == _typeFilter)
                                .toList();
                          }
                          if (_categoryFilter != null) {
                            txns = txns
                                .where((t) => t.category == _categoryFilter)
                                .toList();
                          }
                          if (_sortByAmount) {
                            txns = [...txns]
                              ..sort((a, b) => b.amount.compareTo(a.amount));
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
                              catLabels: catLabels,
                              walletName: (id) =>
                                  walletMap.containsKey(id)
                                      ? walletMap[id]!
                                      : '(ví khác)',
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
      },
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _TxnTile extends ConsumerWidget {
  const _TxnTile({
    required this.txn,
    required this.walletName,
    required this.thresholds,
    required this.catLabels,
  });

  final Txn txn;
  final String Function(String id) walletName;
  final Map<String, int> thresholds;
  final Map<String, String> catLabels;

  String _catLabel(String? id) =>
      id == null ? '—' : (catLabels[id] ?? Categories.label(id));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final repo = ref.read(repositoryProvider);

    final scheme = Theme.of(context).colorScheme;
    final isSpending = txn.type == TxTypes.spending;
    final isTransfer = txn.type == TxTypes.transfer;

    final (IconData icon, Color color) = switch (txn.type) {
      TxTypes.spending => (Icons.south_west, scheme.error),
      TxTypes.earning => (Icons.north_east, Colors.green.shade700),
      _ => (Icons.swap_horiz, scheme.primary),
    };

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
            : _catLabel(txn.category));

    final subtitleParts = <String>[
      TxTypes.labels[txn.type] ?? txn.type,
      if (!isTransfer) _catLabel(txn.category),
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

    return ListTile(
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
      onLongPress: () => _showActionSheet(context, repo, showStar: showStar),
    );
  }

  void _showActionSheet(BuildContext context, FinanceRepository repo,
      {required bool showStar}) {
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
                  showStar ? Icons.star : Icons.star_border,
                  color: Colors.amber.shade600,
                ),
                title: Text(showStar ? 'Bỏ đánh dấu sao' : 'Đánh dấu sao'),
                onTap: () {
                  Navigator.pop(ctx);
                  repo.toggleStar(txn);
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
                if (ok == true) await repo.deleteTxn(txn.id);
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
