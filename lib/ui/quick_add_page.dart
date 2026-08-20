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
import 'widgets/app_icon.dart';

class QuickAddPage extends ConsumerStatefulWidget {
  const QuickAddPage({super.key, this.editing, this.initialType});

  final Txn? editing;
  final String? initialType;

  @override
  ConsumerState<QuickAddPage> createState() => _QuickAddPageState();
}

class _QuickAddPageState extends ConsumerState<QuickAddPage> {
  late String _type;
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  String? _category;
  String? _walletId;
  String? _toWalletId;
  late DateTime _timestamp;
  bool _starred = false;
  bool _categoryTouched = false;
  bool _saving = false;

  bool get _isEdit => widget.editing != null;
  bool get _isTransfer => _type == TxTypes.transfer;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _type = e.type;
      _amount.text = e.amount.toString();
      _desc.text = e.description ?? '';
      _category = e.category;
      _walletId = e.walletId;
      _toWalletId = e.walletToId;
      _timestamp = e.timestamp;
      _starred = e.starred;
      _categoryTouched = true;
    } else {
      _type = widget.initialType ?? TxTypes.spending;
      _timestamp = DateTime.now();
      _category = Categories.fallbackFor(_type);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _onTypeChanged(String t) {
    final suggester = ref.read(suggesterProvider);
    setState(() {
      _type = t;
      if (_isTransfer) {
        _category = null;
        _categoryTouched = false;
      } else {
        _categoryTouched = false;
        _category = suggester.suggest(_desc.text, _type);
      }
    });
  }

  void _onDescChanged(String text) {
    if (_categoryTouched || _isTransfer) return;
    setState(() => _category = ref.read(suggesterProvider).suggest(text, _type));
  }

  Future<void> _pickTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _timestamp,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_timestamp),
    );
    setState(() => _timestamp = DateTime(
          d.year, d.month, d.day,
          t?.hour ?? _timestamp.hour,
          t?.minute ?? _timestamp.minute,
        ));
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save() async {
    final repo = ref.read(repositoryProvider);
    final l10n = AppLocalizations.of(context)!;
    final amount = parseAmount(_amount.text);
    if (amount <= 0) { _snack(l10n.quickAddInvalidAmount); return; }
    if (_walletId == null) {
      _snack(_isTransfer ? l10n.quickAddPickSourceWallet : l10n.quickAddPickWallet);
      return;
    }
    if (_isTransfer) {
      if (_toWalletId == null) { _snack(l10n.quickAddPickDestWallet); return; }
      if (_toWalletId == _walletId) { _snack(l10n.quickAddSameWalletError); return; }
    }

    setState(() => _saving = true);
    final autostar = ref.read(settingsProvider).autostarEnabled;
    try {
      if (_isEdit) {
        final updated = widget.editing!.copyWith(
          type: _type,
          amount: amount,
          description: Value<String?>(_isTransfer ? null : _desc.text.trim()),
          walletId: _walletId!,
          walletToId: Value<String?>(_isTransfer ? _toWalletId : null),
          category: Value<String?>(_isTransfer ? null : _category),
          timestamp: _timestamp,
          starred: _starred,
        );
        await repo.updateTxn(updated, autostarEnabled: autostar);
      } else {
        switch (_type) {
          case TxTypes.spending:
            await repo.addSpending(
              amount: amount, walletId: _walletId!,
              category: _category ?? Categories.fallbackFor(_type),
              description: _desc.text.trim(), timestamp: _timestamp,
              starred: _starred,
              autostarEnabled: autostar,
            );
          case TxTypes.earning:
            await repo.addEarning(
              amount: amount, walletId: _walletId!,
              category: _category ?? Categories.fallbackFor(_type),
              description: _desc.text.trim(), timestamp: _timestamp,
              starred: _starred,
              autostarEnabled: autostar,
            );
          case TxTypes.transfer:
            await repo.addTransfer(
              amount: amount, fromWalletId: _walletId!,
              toWalletId: _toWalletId!, timestamp: _timestamp,
            );
        }
      }
      if (mounted) Navigator.pop(context);
    } on OverspendException {
      _snack(AppLocalizations.of(context)!.overspendError);
    } catch (e) {
      _snack(AppLocalizations.of(context)!.commonUnexpectedError(e.toString()));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repositoryProvider);
    final sym = ref.watch(settingsProvider).currencySymbol;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEdit ? l10n.quickAddEditTitle : l10n.commonQuickAddLabel)),
      body: StreamBuilder<List<Wallet>>(
        stream: repo.watchWallets(),
        builder: (context, wSnap) {
          final wallets = wSnap.data ?? const [];
          if (wallets.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(l10n.quickAddNoWalletMessage)),
            );
          }
          // Load active categories from DB for the current type.
          return StreamBuilder<List<AppCategory>>(
            stream: _isTransfer
                ? const Stream.empty()
                : repo.watchActiveCategories(_type),
            builder: (context, catSnap) {
              // Fall back to hardcoded domain list if DB not ready yet.
              final cats = catSnap.data;
              final catItems = cats != null && cats.isNotEmpty
                  ? cats
                  : _fallbackCats(_type, l10n);

              // Reset category if it's not in the new list.
              if (_category != null &&
                  !catItems.any((c) => c.id == _category)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _category = catItems.first.id);
                });
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_isEdit)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(label: Text(TxTypes.label(l10n, _type))),
                    )
                  else
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(value: TxTypes.spending, label: Text(l10n.txTypeSpending)),
                        ButtonSegment(value: TxTypes.earning, label: Text(l10n.txTypeEarning)),
                        ButtonSegment(value: TxTypes.transfer, label: Text(l10n.txTypeTransfer)),
                      ],
                      selected: {_type},
                      onSelectionChanged: (s) => _onTypeChanged(s.first),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: l10n.fieldAmount, suffixText: sym),
                  ),
                  const SizedBox(height: 16),
                  if (!_isTransfer) ...[
                    TextField(
                      controller: _desc,
                      onChanged: _onDescChanged,
                      decoration: InputDecoration(labelText: l10n.fieldDescription),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: InputDecoration(labelText: l10n.fieldCategory),
                      items: [
                        for (final c in catItems)
                          DropdownMenuItem(value: c.id, child: Text(c.label)),
                      ],
                      onChanged: (v) => setState(() {
                        _category = v;
                        _categoryTouched = true;
                      }),
                    ),
                    const SizedBox(height: 16),
                    _walletDropdown(
                      label: l10n.fieldWallet, value: _walletId, wallets: wallets,
                      onChanged: (v) => setState(() => _walletId = v),
                    ),
                  ] else ...[
                    _walletDropdown(
                      label: l10n.quickAddFromWallet, value: _walletId, wallets: wallets,
                      onChanged: (v) => setState(() => _walletId = v),
                    ),
                    const SizedBox(height: 16),
                    _walletDropdown(
                      label: l10n.quickAddToWallet, value: _toWalletId, wallets: wallets,
                      onChanged: (v) => setState(() => _toWalletId = v),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.schedule),
                      title: Text(l10n.quickAddTimeLabel),
                      subtitle: Text(formatDateTime(_timestamp)),
                      trailing: TextButton(onPressed: _pickTime, child: Text(l10n.commonEdit)),
                    ),
                  ),
                  if (!_isTransfer)
                    SwitchListTile(
                      secondary: AppIcon('star',
                        fallback: _starred ? Icons.star : Icons.star_border,
                        color: Colors.amber.shade600,
                      ),
                      title: Text(l10n.commonMarkStarred),
                      value: _starred,
                      onChanged: (v) => setState(() => _starred = v),
                    ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check),
                    label: Text(_isEdit ? l10n.commonSaveChanges : l10n.commonSave),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _walletDropdown({
    required String label,
    required String? value,
    required List<Wallet> wallets,
    required ValueChanged<String?> onChanged,
  }) {
    final exists = wallets.any((w) => w.id == value);
    return DropdownButtonFormField<String>(
      initialValue: exists ? value : null,
      decoration: InputDecoration(labelText: label),
      items: [for (final w in wallets) DropdownMenuItem(value: w.id, child: Text(w.name))],
      onChanged: onChanged,
    );
  }
}

/// Builds fallback AppCategory-like objects from the hardcoded domain list
/// so the dropdown is never empty while the DB query is loading.
List<AppCategory> _fallbackCats(String type, AppLocalizations l10n) {
  final ids = Categories.forType(type);
  return [
    for (var i = 0; i < ids.length; i++)
      AppCategory(
        id: ids[i],
        label: Categories.label(l10n, ids[i]),
        kind: type,
        threshold: 0,
        isDefault: true,
        archived: false,
        sortOrder: i,
      ),
  ];
}
