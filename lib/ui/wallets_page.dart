import 'package:flutter/material.dart';

import '../data/database.dart';
import '../format.dart';
import '../main.dart' show repository;
import '../models/domain.dart';

class WalletsPage extends StatelessWidget {
  const WalletsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Wallet>>(
      stream: repository.watchWallets(),
      builder: (context, wSnap) {
        final wallets = wSnap.data ?? const [];
        return StreamBuilder<List<Txn>>(
          stream: repository.watchTxns(),
          builder: (context, tSnap) {
            final txns = tSnap.data ?? const [];
            if (wallets.isEmpty) {
              return _Empty(onAdd: () => _addWalletDialog(context));
            }
            final total = wallets.fold<int>(
                0, (sum, w) => sum + repository.balanceOf(w, txns));
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
                      subtitle: Text(WalletKinds.label(w.type)),
                      trailing: Text(
                        formatVnd(repository.balanceOf(w, txns)),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onLongPress: () => _confirmDelete(context, w),
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _addWalletDialog(context),
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

  Future<void> _confirmDelete(BuildContext context, Wallet w) async {
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
    if (ok == true) await repository.deleteWallet(w.id);
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

// A floating "add wallet" entry point lives on this page via a dialog so the
// shared FAB stays dedicated to adding transactions.
Future<void> _addWalletDialog(BuildContext context) async {
  final nameCtrl = TextEditingController();
  final balCtrl = TextEditingController();
  var kind = WalletKinds.cash;

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
                ButtonSegment(value: WalletKinds.cash, label: Text('Tiền mặt')),
                ButtonSegment(value: WalletKinds.bank, label: Text('Ngân hàng')),
              ],
              selected: {kind},
              onSelectionChanged: (s) => setState(() => kind = s.first),
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
              await repository.addWallet(
                name: name,
                initialBalance: parseAmount(balCtrl.text),
                type: kind,
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
Future<void> showAddWalletDialog(BuildContext context) =>
    _addWalletDialog(context);
