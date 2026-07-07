import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../format.dart';
import '../models/domain.dart';
import '../providers.dart';
import '../repositories/finance_repository.dart';
import '../services/bank/bank_notification_parser.dart';

// Curated bank options for the link picker (ADR-0014).
const _kBankOptions = [
  (label: 'OCB', pkg: BankPackages.ocb),
  (label: 'MB', pkg: BankPackages.mb),
  (label: 'Techcombank', pkg: BankPackages.techcombank),
];

String? _bankLabel(String? pkg) {
  if (pkg == null) return null;
  for (final b in _kBankOptions) {
    if (b.pkg == pkg) return b.label;
  }
  return pkg;
}

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
            if (wallets.isEmpty) {
              return _Empty(onAdd: () => _addWalletDialog(context, repo));
            }
            final total =
                balances.values.fold<int>(0, (sum, b) => sum + b);
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  child: ListTile(
                    title: const Text('Tổng số dư'),
                    trailing: Text(formatVnd(total),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
                for (final w in wallets)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(w.type == WalletKinds.bank
                            ? Icons.account_balance
                            : Icons.payments),
                      ),
                      title: Text(w.name),
                      subtitle: Text([
                        WalletKinds.label(w.type),
                        if (_bankLabel(w.packageName) != null)
                          _bankLabel(w.packageName)!,
                      ].join(' · ')),
                      trailing: Text(
                        formatVnd(balances[w.id] ?? 0),
                        style:
                            const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onLongPress: () =>
                          _walletActionSheet(context, w, repo),
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _addWalletDialog(context, repo),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm ví'),
                ),
                const SizedBox(height: 80),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _walletActionSheet(
      BuildContext context, Wallet w, FinanceRepository repo) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Sửa liên kết ngân hàng'),
              onTap: () {
                Navigator.pop(ctx);
                _editBankLinkDialog(context, w, repo);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
              title: Text('Xoá ví',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, w, repo);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editBankLinkDialog(
      BuildContext context, Wallet w, FinanceRepository repo) async {
    String? selectedPkg = w.packageName;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Liên kết ngân hàng'),
          content: DropdownButtonFormField<String?>(
            initialValue: selectedPkg,
            decoration:
                const InputDecoration(labelText: 'Ngân hàng'),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('— Không liên kết —')),
              for (final b in _kBankOptions)
                DropdownMenuItem<String?>(
                    value: b.pkg, child: Text(b.label)),
            ],
            onChanged: (v) => setState(() => selectedPkg = v),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Huỷ')),
            FilledButton(
              onPressed: () async {
                final newPkg = selectedPkg;
                if (newPkg == w.packageName) {
                  Navigator.pop(context);
                  return;
                }
                if (newPkg != null) {
                  // Uniqueness check — exclude the wallet being edited.
                  final existing =
                      await repo.walletByPackageName(newPkg);
                  if (existing != null && existing.id != w.id) {
                    if (!context.mounted) return;
                    final move = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title:
                            const Text('Ngân hàng đã được liên kết'),
                        content: Text(
                          'Ngân hàng này đang liên kết với ví '
                          '"${existing.name}". Chuyển sang ví này?',
                        ),
                        actions: [
                          TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, false),
                              child: const Text('Huỷ')),
                          FilledButton(
                              onPressed: () =>
                                  Navigator.pop(context, true),
                              child: const Text('Chuyển')),
                        ],
                      ),
                    );
                    if (move != true) return;
                    await repo.reassignWalletBankLink(newPkg, w.id);
                    if (context.mounted) Navigator.pop(context);
                    return;
                  }
                }
                await repo.updateWalletPackageName(w.id, newPkg);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, Wallet w, FinanceRepository repo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Xoá ví "${w.name}"?'),
        content: const Text(
            'Giao dịch liên quan vẫn được giữ lại nhưng sẽ không còn ví tham chiếu.'),
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
    if (ok == true) await repo.deleteWallet(w.id);
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_balance_wallet_outlined, size: 64),
          const SizedBox(height: 12),
          const Text('Chưa có ví nào.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Thêm ví'),
          ),
        ],
      ),
    );
  }
}

Future<void> _addWalletDialog(
    BuildContext context, FinanceRepository repository) async {
  final nameCtrl = TextEditingController();
  final balCtrl = TextEditingController();
  var kind = WalletKinds.cash;
  String? linkedPkg;

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Thêm ví'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Tên ví'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: balCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Số dư hiện tại (₫)'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: WalletKinds.cash, label: Text('Tiền mặt')),
                ButtonSegment(
                    value: WalletKinds.bank, label: Text('Ngân hàng')),
              ],
              selected: {kind},
              onSelectionChanged: (s) => setState(() => kind = s.first),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: linkedPkg,
              decoration: const InputDecoration(
                  labelText: 'Ngân hàng liên kết'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('— Không —')),
                for (final b in _kBankOptions)
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
              child: const Text('Huỷ')),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final pkg = linkedPkg;

              if (pkg != null) {
                // Uniqueness check before inserting.
                final existing =
                    await repository.walletByPackageName(pkg);
                if (existing != null) {
                  if (!context.mounted) return;
                  final move = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title:
                          const Text('Ngân hàng đã được liên kết'),
                      content: Text(
                        'Ngân hàng này đang liên kết với ví '
                        '"${existing.name}". Chuyển sang ví mới?',
                      ),
                      actions: [
                        TextButton(
                            onPressed: () =>
                                Navigator.pop(context, false),
                            child: const Text('Huỷ')),
                        FilledButton(
                            onPressed: () =>
                                Navigator.pop(context, true),
                            child: const Text('Chuyển')),
                      ],
                    ),
                  );
                  if (move != true) return;
                  // Create wallet without pkg first, then move link atomically.
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
            child: const Text('Lưu'),
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
