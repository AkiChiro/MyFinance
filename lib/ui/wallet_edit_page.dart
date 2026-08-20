import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../format.dart';
import '../l10n/generated/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack(l10n.walletEditNameRequired);
      return;
    }
    final newBalance = parseAmount(_balance.text);
    final balanceChanged = newBalance != widget.wallet.initialBalance;
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
              title: Text(l10n.walletsBankConflictTitle),
              content: Text(
                l10n.walletEditBankConflictBody(existing.name),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l10n.commonCancel)),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l10n.walletBankLinkMoveAction)),
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
            initialBalance: newBalance,
            type: _type,
            packageName: const Value(null),
            resetTransactions: balanceChanged,
          );
          await repo.reassignWalletBankLink(newPkg, widget.wallet.id);
          if (context.mounted) Navigator.pop(context);
          return;
        }
      }
      await repo.updateWallet(
        id: widget.wallet.id,
        name: name,
        initialBalance: newBalance,
        type: _type,
        packageName: Value(newPkg),
        resetTransactions: balanceChanged,
      );
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      _snack(l10n.commonUnexpectedError(e.toString()));
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, FinanceRepository repo) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.walletEditDeleteConfirmTitle(widget.wallet.name)),
        content: Text(l10n.walletEditDeleteConfirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(
                  Theme.of(context).colorScheme.error),
            ),
            child: Text(l10n.commonDelete,
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.walletEditTitle),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.error),
            tooltip: l10n.walletEditDeleteTooltip,
            onPressed: _saving ? null : () => _confirmDelete(context, repo),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: l10n.walletsNameField),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _balance,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n.walletEditInitialBalanceField,
              helperText: l10n.walletEditBalanceHelperText,
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                  value: WalletKinds.cash, label: Text(l10n.walletKindCash)),
              ButtonSegment(
                  value: WalletKinds.bank, label: Text(l10n.walletKindBank)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: _pkg,
            decoration:
                InputDecoration(labelText: l10n.walletsBankLinkField),
            items: [
              DropdownMenuItem<String?>(
                  value: null, child: Text(l10n.walletEditBankLinkNoneAlt)),
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
            label: Text(l10n.commonSaveChanges),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
