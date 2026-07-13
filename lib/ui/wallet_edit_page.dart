import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../format.dart';
import '../models/domain.dart';
import '../providers.dart';
import '../repositories/finance_repository.dart';
import '../services/bank/bank_notification_parser.dart';

class WalletEditPage extends ConsumerStatefulWidget {
  const WalletEditPage({super.key, required this.wallet});

  final Wallet wallet;

  @override
  ConsumerState<WalletEditPage> createState() => _WalletEditPageState();
}

class _WalletEditPageState extends ConsumerState<WalletEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _balance;
  late String _type;
  late String? _pkg;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.wallet.name);
    _balance =
        TextEditingController(text: widget.wallet.initialBalance.toString());
    _type = widget.wallet.type;
    _pkg = widget.wallet.packageName;
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save(BuildContext context, FinanceRepository repo) async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack('Vui lòng nhập tên ví.');
      return;
    }
    setState(() => _saving = true);
    try {
      final newPkg = _pkg;
      // If the bank link changed to a non-null value, check uniqueness.
      if (newPkg != null && newPkg != widget.wallet.packageName) {
        final existing = await repo.walletByPackageName(newPkg);
        if (existing != null && existing.id != widget.wallet.id) {
          if (!context.mounted) return;
          final move = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Ngân hàng đã được liên kết'),
              content: Text(
                'Ngân hàng này đang liên kết với ví "${existing.name}". '
                'Chuyển sang ví này?',
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Huỷ')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Chuyển')),
              ],
            ),
          );
          if (move != true) {
            setState(() => _saving = false);
            return;
          }
          // Clear our pkg first so reassign can move it cleanly.
          await repo.updateWallet(
            id: widget.wallet.id,
            name: name,
            initialBalance: parseAmount(_balance.text),
            type: _type,
            packageName: const Value(null),
          );
          await repo.reassignWalletBankLink(newPkg, widget.wallet.id);
          if (context.mounted) Navigator.pop(context);
          return;
        }
      }
      await repo.updateWallet(
        id: widget.wallet.id,
        name: name,
        initialBalance: parseAmount(_balance.text),
        type: _type,
        packageName: Value(newPkg),
      );
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Có lỗi xảy ra: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, FinanceRepository repo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Xoá ví "${widget.wallet.name}"?'),
        content: const Text(
            'Giao dịch liên quan vẫn được giữ lại nhưng sẽ không còn ví tham chiếu.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(
                  Theme.of(context).colorScheme.error),
            ),
            child: Text('Xoá',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onError)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await repo.deleteWallet(widget.wallet.id);
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sửa ví'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.error),
            tooltip: 'Xoá ví',
            onPressed: _saving ? null : () => _confirmDelete(context, repo),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Tên ví'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _balance,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Số dư ban đầu (₫)',
              helperText:
                  'Thay đổi giá trị này sẽ ảnh hưởng đến số dư hiện tại.',
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: WalletKinds.cash, label: Text('Tiền mặt')),
              ButtonSegment(
                  value: WalletKinds.bank, label: Text('Ngân hàng')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: _pkg,
            decoration:
                const InputDecoration(labelText: 'Ngân hàng liên kết'),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('— Không liên kết —')),
              for (final b in kBankPickerOptions)
                DropdownMenuItem<String?>(
                    value: b.pkg, child: Text(b.label)),
            ],
            onChanged: (v) => setState(() => _pkg = v),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _saving ? null : () => _save(context, repo),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: const Text('Lưu thay đổi'),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
