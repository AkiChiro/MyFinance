import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../format.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/domain.dart';
import '../providers.dart';
import '../repositories/finance_repository.dart';
import '../services/bank/bank_notification_parser.dart';
import 'wallet_edit_page.dart';
import 'widgets/app_icon.dart';
import 'widgets/hero_balance_card.dart';
import 'widgets/recent_activity_preview.dart';

class WalletsPage extends ConsumerWidget {
  const WalletsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    return StreamBuilder<List<Wallet>>(
      stream: repo.watchWallets(),
      builder: (context, wSnap) {
        final wallets = wSnap.data ?? const [];
        return StreamBuilder<Map<String, int>>(
          stream: repo.watchWalletBalances(),
          builder: (context, bSnap) {
            final balances = bSnap.data ?? const {};
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: wallets.isEmpty
                  ? _Empty(
                      key: const ValueKey('empty'),
                      onAdd: () => _addWalletDialog(context, repo))
                  : _WalletsList(
                      key: const ValueKey('list'),
                      wallets: wallets,
                      balances: balances,
                      repo: repo,
                    ),
            );
          },
        );
      },
    );
  }
}

class _WalletsList extends StatelessWidget {
  const _WalletsList(
      {super.key, required this.wallets, required this.balances, required this.repo});
  final List<Wallet> wallets;
  final Map<String, int> balances;
  final FinanceRepository repo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final total = balances.values.fold<int>(0, (sum, b) => sum + b);
    final walletMap = {for (final w in wallets) w.id: w.name};
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        HeroBalanceCard(total: total),
        const SizedBox(height: 12),
        RecentActivityPreview(walletMap: walletMap),
        const SizedBox(height: 12),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: wallets.length,
          itemBuilder: (context, i) {
            final w = wallets[i];
            return Card(
              key: ValueKey(w.id),
              child: ListTile(
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_handle),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      child: AppIcon(
                        w.type == WalletKinds.cash
                            ? 'wallet_cash'
                            : 'wallet_bank',
                        fallback: w.type == WalletKinds.cash
                            ? Icons.payments_outlined
                            : Icons.account_balance_outlined,
                      ),
                    ),
                  ],
                ),
                title: Text(w.name),
                subtitle: Text([
                  WalletKinds.label(l10n, w.type),
                  if (bankLabel(w.packageName) != null)
                    bankLabel(w.packageName)!,
                ].join(' · ')),
                trailing: Text(
                  formatVnd(balances[w.id] ?? 0),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => WalletEditPage(wallet: w),
                  ),
                ),
              ),
            );
          },
          onReorder: (oldIndex, newIndex) {
            if (newIndex > oldIndex) newIndex--;
            final reordered = [...wallets];
            reordered.insert(newIndex, reordered.removeAt(oldIndex));
            repo.updateWalletsOrder(reordered.map((w) => w.id).toList());
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _addWalletDialog(context, repo),
          icon: const Icon(Icons.add),
          label: Text(l10n.walletsAddButton),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({super.key, required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance_wallet_outlined,
                  size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(l10n.walletsEmptyMessage, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text(l10n.walletsAddButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _addWalletDialog(
    BuildContext context, FinanceRepository repository) async {
  final l10n = AppLocalizations.of(context)!;
  final nameCtrl = TextEditingController();
  final balCtrl = TextEditingController();
  var kind = WalletKinds.cash;
  String? linkedPkg;

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(l10n.walletsAddButton),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: l10n.walletsNameField),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: balCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: l10n.walletsCurrentBalanceField),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                    value: WalletKinds.cash, label: Text(l10n.walletKindCash)),
                ButtonSegment(
                    value: WalletKinds.bank, label: Text(l10n.walletKindBank)),
              ],
              selected: {kind},
              onSelectionChanged: (s) => setState(() => kind = s.first),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: linkedPkg,
              decoration:
                  InputDecoration(labelText: l10n.walletsBankLinkField),
              items: [
                DropdownMenuItem<String?>(
                    value: null, child: Text(l10n.walletsBankLinkNone)),
                for (final b in kBankPickerOptions)
                  DropdownMenuItem<String?>(
                      value: b.pkg, child: Text(b.label)),
              ],
              onChanged: (v) => setState(() => linkedPkg = v),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final pkg = linkedPkg;

              if (pkg != null) {
                final existing = await repository.walletByPackageName(pkg);
                if (existing != null) {
                  if (!context.mounted) return;
                  final move = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(l10n.walletsBankConflictTitle),
                      content: Text(
                        l10n.walletsBankConflictBody(existing.name),
                      ),
                      actions: [
                        TextButton(
                            onPressed: () =>
                                Navigator.pop(context, false),
                            child: Text(l10n.commonCancel)),
                        FilledButton(
                            onPressed: () =>
                                Navigator.pop(context, true),
                            child: Text(l10n.walletBankLinkMoveAction)),
                      ],
                    ),
                  );
                  if (move != true) return;
                  final newId = await repository.addWallet(
                    name: name,
                    initialBalance: parseAmount(balCtrl.text),
                    type: kind,
                  );
                  await repository.reassignWalletBankLink(pkg, newId);
                  if (context.mounted) Navigator.pop(context);
                  return;
                }
              }

              await repository.addWallet(
                name: name,
                initialBalance: parseAmount(balCtrl.text),
                type: kind,
                packageName: pkg,
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    ),
  );
}

/// Exposed so other screens can trigger the same add-wallet flow if needed.
Future<void> showAddWalletDialog(
        BuildContext context, FinanceRepository repository) =>
    _addWalletDialog(context, repository);
