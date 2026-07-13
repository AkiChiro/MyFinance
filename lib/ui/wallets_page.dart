import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../format.dart';
import '../models/domain.dart';
import '../providers.dart';
import '../repositories/finance_repository.dart';
import '../services/bank/bank_notification_parser.dart';
import 'wallet_edit_page.dart';

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
                    trailing: Text(
                      formatVnd(total),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
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
                        leading: ReorderableDragStartListener(
                          index: i,
                          child: const Icon(Icons.drag_handle),
                        ),
                        title: Text(w.name),
                        subtitle: Text([
                          WalletKinds.label(w.type),
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
                    repo.updateWalletsOrder(
                        reordered.map((w) => w.id).toList());
                  },
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
              decoration:
                  const InputDecoration(labelText: 'Ngân hàng liên kết'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('— Không —')),
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
              child: const Text('Huỷ')),
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
                      title: const Text('Ngân hàng đã được liên kết'),
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
