import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/database.dart';
import '../format.dart';
import '../main.dart' show repository, settings, suggester;
import '../models/domain.dart';
import '../repositories/finance_repository.dart';

class QuickAddPage extends StatefulWidget {
  const QuickAddPage({super.key, this.editing, this.initialType});

  final Txn? editing;
  final String? initialType;

  @override
  State<QuickAddPage> createState() => _QuickAddPageState();
}

class _QuickAddPageState extends State<QuickAddPage> {
  late String _type;
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  String? _category;
  String? _walletId;
  String? _toWalletId;
  late DateTime _timestamp;
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
    setState(() => _category = suggester.suggest(text, _type));
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
    final amount = parseAmount(_amount.text);
    if (amount <= 0) { _snack('Vui lòng nhập số tiền hợp lệ.'); return; }
    if (_walletId == null) { _snack(_isTransfer ? 'Chọn ví nguồn.' : 'Chọn ví.'); return; }
    if (_isTransfer) {
      if (_toWalletId == null) { _snack('Chọn ví đích.'); return; }
      if (_toWalletId == _walletId) { _snack('Ví nguồn và ví đích phải khác nhau.'); return; }
    }

    setState(() => _saving = true);
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
        );
        await repository.updateTxn(updated);
      } else {
        switch (_type) {
          case TxTypes.spending:
            await repository.addSpending(
              amount: amount, walletId: _walletId!,
              category: _category ?? Categories.fallbackFor(_type),
              description: _desc.text.trim(), timestamp: _timestamp,
            );
          case TxTypes.earning:
            await repository.addEarning(
              amount: amount, walletId: _walletId!,
              category: _category ?? Categories.fallbackFor(_type),
              description: _desc.text.trim(), timestamp: _timestamp,
            );
          case TxTypes.transfer:
            await repository.addTransfer(
              amount: amount, fromWalletId: _walletId!,
              toWalletId: _toWalletId!, timestamp: _timestamp,
            );
        }
      }
      if (mounted) Navigator.pop(context);
    } on OverspendException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Có lỗi xảy ra: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sym = settings.currencySymbol;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Sửa giao dịch' : 'Thêm nhanh')),
      body: StreamBuilder<List<Wallet>>(
        stream: repository.watchWallets(),
        builder: (context, wSnap) {
          final wallets = wSnap.data ?? const [];
          if (wallets.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Hãy thêm ít nhất một ví trước khi ghi giao dịch.')),
            );
          }
          // Load active categories from DB for the current type.
          return StreamBuilder<List<AppCategory>>(
            stream: _isTransfer
                ? const Stream.empty()
                : repository.watchActiveCategories(_type),
            builder: (context, catSnap) {
              // Fall back to hardcoded domain list if DB not ready yet.
              final cats = catSnap.data;
              final catItems = cats != null && cats.isNotEmpty
                  ? cats
                  : _fallbackCats(_type);

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
                      child: Chip(label: Text(TxTypes.labels[_type] ?? _type)),
                    )
                  else
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: TxTypes.spending, label: Text('Chi tiêu')),
                        ButtonSegment(value: TxTypes.earning, label: Text('Thu nhập')),
                        ButtonSegment(value: TxTypes.transfer, label: Text('Chuyển khoản')),
                      ],
                      selected: {_type},
                      onSelectionChanged: (s) => _onTypeChanged(s.first),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: 'Số tiền', suffixText: sym),
                  ),
                  const SizedBox(height: 16),
                  if (!_isTransfer) ...[
                    TextField(
                      controller: _desc,
                      onChanged: _onDescChanged,
                      decoration: const InputDecoration(labelText: 'Mô tả'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(labelText: 'Danh mục'),
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
                      label: 'Ví', value: _walletId, wallets: wallets,
                      onChanged: (v) => setState(() => _walletId = v),
                    ),
                  ] else ...[
                    _walletDropdown(
                      label: 'Từ ví', value: _walletId, wallets: wallets,
                      onChanged: (v) => setState(() => _walletId = v),
                    ),
                    const SizedBox(height: 16),
                    _walletDropdown(
                      label: 'Đến ví', value: _toWalletId, wallets: wallets,
                      onChanged: (v) => setState(() => _toWalletId = v),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.schedule),
                      title: const Text('Thời gian'),
                      subtitle: Text(formatDateTime(_timestamp)),
                      trailing: TextButton(onPressed: _pickTime, child: const Text('Sửa')),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check),
                    label: Text(_isEdit ? 'Lưu thay đổi' : 'Lưu'),
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
List<AppCategory> _fallbackCats(String type) {
  final ids = Categories.forType(type);
  return [
    for (var i = 0; i < ids.length; i++)
      AppCategory(
        id: ids[i],
        label: Categories.label(ids[i]),
        kind: type,
        threshold: 0,
        isDefault: true,
        archived: false,
        sortOrder: i,
      ),
  ];
}
