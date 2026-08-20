import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../format.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/domain.dart';
import '../providers.dart';
import '../repositories/finance_repository.dart';
import 'captures_page.dart';
import 'category_colors.dart';
import 'quick_add_page.dart';
import 'widgets/app_icon.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  // null = sort by timestamp, 'asc' = amount lowest first, 'desc' = amount highest first
  String? _sortDirection;

  Widget _buildFilterBar(BuildContext context, List<AppCategory> allCats,
      Map<String, String> catLabels) {
    final l10n = AppLocalizations.of(context)!;
    final typeFilter = ref.watch(txnTypeFilterProvider);
    final categoryFilter = ref.watch(txnCategoryFilterProvider);
    final starredOnly = ref.watch(txnStarredOnlyProvider);
    final monthMode = ref.watch(monthModeProvider);

    final sortLabel = switch (_sortDirection) {
      'asc' => l10n.txnsAmountAsc,
      'desc' => l10n.txnsAmountDesc,
      _ => l10n.fieldAmount,
    };

    // Folds the type ChoiceChip and the category picker into one control:
    // inactive shows just the type label; tapping activates it (and reveals
    // the dropdown arrow); tapping again while active opens the category
    // picker, after which the chip's label switches to the category name.
    Widget typeCategoryChip({
      required String type,
      required String typeLabel,
      required List<AppCategory> categoriesForType,
    }) {
      final isActive = typeFilter == type;
      final currentLabel = isActive && categoryFilter != null
          ? (catLabels[categoryFilter] ?? categoryFilter)
          : typeLabel;
      return ChoiceChip(
        showCheckmark: false,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(currentLabel),
            if (isActive) const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
        selected: isActive,
        onSelected: (_) {
          if (!isActive) {
            ref.read(txnTypeFilterProvider.notifier).state = type;
            ref.read(txnCategoryFilterProvider.notifier).state = null;
          } else {
            _pickCategory(context, categoriesForType);
          }
        },
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          ChoiceChip(
            label: Text(monthMode ? l10n.txnsChipMonth : l10n.txnsChipAll),
            selected: typeFilter == null,
            onSelected: (_) {
              if (typeFilter != null) {
                ref.read(txnTypeFilterProvider.notifier).state = null;
                ref.read(txnCategoryFilterProvider.notifier).state = null;
              } else {
                ref.read(monthModeProvider.notifier).state = !monthMode;
              }
            },
          ),
          const SizedBox(width: 8),
          typeCategoryChip(
            type: TxTypes.spending,
            typeLabel: l10n.txTypeSpending,
            categoriesForType: allCats
                .where((c) => c.kind == TxTypes.spending && !c.archived)
                .toList(),
          ),
          const SizedBox(width: 8),
          typeCategoryChip(
            type: TxTypes.earning,
            typeLabel: l10n.txTypeEarning,
            categoriesForType: allCats
                .where((c) => c.kind == TxTypes.earning && !c.archived)
                .toList(),
          ),
          const SizedBox(width: 8),
          FilterChip(
            avatar: AppIcon('star',
                fallback: Icons.star,
                size: 14,
                color: starredOnly ? Colors.amber.shade700 : null),
            label: Text(l10n.txnsChipStarred),
            selected: starredOnly,
            onSelected: (v) =>
                ref.read(txnStarredOnlyProvider.notifier).state = v,
          ),
          const SizedBox(width: 8),
          FilterChip(
            avatar: const Icon(Icons.sort, size: 14),
            label: Text(sortLabel),
            selected: _sortDirection != null,
            onSelected: (_) => setState(() {
              _sortDirection = switch (_sortDirection) {
                null => 'asc',
                'asc' => 'desc',
                _ => null,
              };
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCategory(
      BuildContext context, List<AppCategory> cats) async {
    final l10n = AppLocalizations.of(context)!;
    // Use a list wrapper so we can distinguish "dismissed" (null) from
    // "all selected" ([null]) and "category selected" ([id]).
    final picked = await showDialog<List<String?>>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(l10n.txnsPickCategoryTitle),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, [null]),
            child: Text(l10n.txnsChipAll),
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
      ref.read(txnCategoryFilterProvider.notifier).state = picked[0];
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repositoryProvider);
    final l10n = AppLocalizations.of(context)!;

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
                      l10n.pendingCaptureBanner(count),
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
                  return StreamBuilder<List<Txn>>(
                    stream: repo.watchTxns(),
                    builder: (context, tSnap) {
                      var txns = tSnap.data ?? const [];
                      // Apply filters.
                      final monthMode = ref.watch(monthModeProvider);
                      final selectedMonth = ref.watch(selectedMonthProvider);
                      final starredOnly = ref.watch(txnStarredOnlyProvider);
                      final typeFilter = ref.watch(txnTypeFilterProvider);
                      final categoryFilter = ref.watch(txnCategoryFilterProvider);
                      if (monthMode) {
                        txns = txns
                            .where((t) =>
                                t.timestamp.year == selectedMonth.year &&
                                t.timestamp.month == selectedMonth.month)
                            .toList();
                      }
                      if (starredOnly) {
                        txns = txns.where((t) => t.starred).toList();
                      }
                      if (typeFilter != null) {
                        txns = txns
                            .where((t) => t.type == typeFilter)
                            .toList();
                      }
                      if (categoryFilter != null) {
                        // Coalesce a null category into its type's synthetic
                        // bucket, mirroring the analytics SQL's own
                        // COALESCE(category, 'others'|'others_earn') — so a
                        // "Khác" drill-down/filter includes uncategorized
                        // transactions too, the same way the tapped total did.
                        txns = txns.where((t) {
                          final effectiveCat = t.category ??
                              (t.type == TxTypes.earning
                                  ? 'others_earn'
                                  : 'others');
                          return effectiveCat == categoryFilter;
                        }).toList();
                      }
                      if (_sortDirection == 'asc') {
                        txns = [...txns]
                          ..sort((a, b) => a.amount.compareTo(b.amount));
                      } else if (_sortDirection == 'desc') {
                        txns = [...txns]
                          ..sort((a, b) => b.amount.compareTo(a.amount));
                      }

                      final emptyMessage = starredOnly
                          ? l10n.txnsEmptyStarred
                          : monthMode
                              ? l10n.txnsEmptyMonth
                              : l10n.txnsEmptyAll;

                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: txns.isEmpty
                            ? _TxnsEmpty(
                                key: const ValueKey('empty'), message: emptyMessage)
                            : ListView.builder(
                                key: const ValueKey('list'),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: txns.length,
                                itemBuilder: (context, i) => _TxnTile(
                                  txn: txns[i],
                                  catLabels: catLabels,
                                  walletName: (id) => walletMap.containsKey(id)
                                      ? walletMap[id]!
                                      : l10n.txnsOtherWallet,
                                ),
                              ),
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

// ── Empty state ─────────────────────────────────────────────────────────────

class _TxnsEmpty extends StatelessWidget {
  const _TxnsEmpty({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _TxnTile extends ConsumerWidget {
  const _TxnTile({
    required this.txn,
    required this.walletName,
    required this.catLabels,
  });

  final Txn txn;
  final String Function(String id) walletName;
  final Map<String, String> catLabels;

  String _catLabel(AppLocalizations l10n, String? id) =>
      id == null ? '—' : (catLabels[id] ?? Categories.label(l10n, id));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final repo = ref.read(repositoryProvider);
    final l10n = AppLocalizations.of(context)!;

    final scheme = Theme.of(context).colorScheme;
    final isSpending = txn.type == TxTypes.spending;
    final isTransfer = txn.type == TxTypes.transfer;

    final (String iconSlot, IconData icon) = switch (txn.type) {
      TxTypes.spending => ('type_spending', Icons.south_west),
      TxTypes.earning => ('type_earning', Icons.north_east),
      _ => ('type_transfer', Icons.swap_horiz),
    };
    // Amount text stays semantic (spend/earn/transfer) so it's still a
    // 1-glance scan; the icon uses per-category color for richer info.
    final amountColor = switch (txn.type) {
      TxTypes.spending => scheme.error,
      TxTypes.earning => Colors.green.shade700,
      _ => scheme.primary,
    };
    final iconColor = switch (txn.type) {
      TxTypes.spending => spendColor(txn.category),
      TxTypes.earning => earnColor(txn.category),
      _ => scheme.primary,
    };

    String resolveWallet(String? id, String? snapshot) {
      if (id == null || id.isEmpty) return snapshot ?? l10n.txnsOtherWallet;
      final live = walletName(id);
      if (live != l10n.txnsOtherWallet) return live;
      return snapshot ?? l10n.txnsOtherWallet;
    }

    final title = isTransfer
        ? '${resolveWallet(txn.walletId, txn.walletFromName)} → '
            '${resolveWallet(txn.walletToId, txn.walletToName)}'
        : (txn.description?.isNotEmpty == true
            ? txn.description!
            : _catLabel(l10n, txn.category));

    final subtitleParts = <String>[
      TxTypes.label(l10n, txn.type),
      if (!isTransfer) _catLabel(l10n, txn.category),
      if (!isTransfer) resolveWallet(txn.walletId, txn.walletFromName),
      formatDateTime(txn.timestamp),
    ];

    final sym = settings.currencySymbol;
    final suf = settings.currencySuffix;
    final amountText = isTransfer
        ? formatMoney(txn.amount, symbol: sym, suffix: suf)
        : formatSigned(txn.amount,
            negative: isSpending, symbol: sym, suffix: suf);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconColor.withValues(alpha: 0.12),
        child: AppIcon(iconSlot, fallback: icon, color: iconColor),
      ),
      title: Row(
        children: [
          Expanded(
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (txn.starred)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: AppIcon('star',
                  fallback: Icons.star, size: 16, color: Colors.amber.shade600),
            ),
          if (txn.imported)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _Chip(label: l10n.txnsImportedBadge, scheme: scheme),
            ),
        ],
      ),
      subtitle: Text(subtitleParts.join(' · '),
          maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(amountText,
          style: TextStyle(color: amountColor, fontWeight: FontWeight.w600)),
      onTap: txn.imported
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => QuickAddPage(editing: txn),
              )),
      onLongPress: () => _showActionSheet(context, repo, l10n),
    );
  }

  void _showActionSheet(
      BuildContext context, FinanceRepository repo, AppLocalizations l10n) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!txn.imported) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l10n.commonEdit),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => QuickAddPage(editing: txn),
                  ));
                },
              ),
              ListTile(
                leading: AppIcon('star',
                  fallback: txn.starred ? Icons.star : Icons.star_border,
                  color: Colors.amber.shade600,
                ),
                title: Text(
                    txn.starred ? l10n.txnsUnmarkStarred : l10n.commonMarkStarred),
                onTap: () {
                  Navigator.pop(ctx);
                  repo.toggleStar(txn);
                },
              ),
            ],
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
              title: Text(l10n.commonDelete,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(l10n.txnsDeleteConfirmTitle),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(l10n.commonCancel)),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(l10n.commonDelete)),
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
