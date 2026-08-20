import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../format.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/domain.dart';
import '../providers.dart';

class CaptureConfirmPage extends ConsumerStatefulWidget {
  const CaptureConfirmPage({super.key, required this.capture});

  final NotificationCapture capture;

  @override
  ConsumerState<CaptureConfirmPage> createState() =>
      _CaptureConfirmPageState();
}

class _CaptureConfirmPageState extends ConsumerState<CaptureConfirmPage> {
  final _amount = TextEditingController();
  late CaptureDirection _direction;
  String? _walletId;
  String? _category;
  bool _starred = false;
  late DateTime _timestamp;
  bool _saving = false;

  NotificationCapture get _capture => widget.capture;
  bool get _isUnparsed => _capture.parseStatus == ParseStatus.unparsed;

  String get _txType =>
      _direction == CaptureDirection.income ? TxTypes.earning : TxTypes.spending;

  @override
  void initState() {
    super.initState();
    _timestamp = _capture.capturedAt;
    _walletId = _capture.suggestedWalletId;
    if (!_isUnparsed && _capture.direction != null) {
      _direction = _capture.direction!;
      if (_capture.amount != null) {
        _amount.text = _capture.amount.toString();
      }
    } else {
      _direction = CaptureDirection.expense;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _onDirectionChanged(CaptureDirection dir) {
    setState(() {
      _direction = dir;
      _category = null;
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickDate() async {
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

  Future<void> _confirm(List<Wallet> wallets) async {
    final repo = ref.read(repositoryProvider);
    final l10n = AppLocalizations.of(context)!;
    final amount = parseAmount(_amount.text);
    if (amount <= 0) {
      _snack(l10n.quickAddInvalidAmount);
      return;
    }
    if (_walletId == null) {
      _snack(l10n.captureConfirmPickWallet);
      return;
    }

    setState(() => _saving = true);
    try {
      await repo.confirmCapture(
        _capture.id,
        walletId: _walletId!,
        amount: amount,
        direction: _direction,
        category: _category,
        starred: _starred,
        timestamp: _timestamp,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack(l10n.commonUnexpectedError(e.toString()));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _dismiss() async {
    final repo = ref.read(repositoryProvider);
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.captureConfirmDismissConfirmTitle),
        content: Text(l10n.captureConfirmDismissConfirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.captureConfirmDismissAction)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await repo.dismissCapture(_capture.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repositoryProvider);
    final sym = ref.watch(settingsProvider).currencySymbol;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title:
            Text(_isUnparsed ? l10n.captureConfirmManualTitle : l10n.captureConfirmTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _dismiss,
            child: Text(l10n.captureConfirmDismissAction),
          ),
        ],
      ),
      body: StreamBuilder<List<Wallet>>(
        stream: repo.watchWallets(),
        builder: (context, wSnap) {
          final wallets = wSnap.data ?? const [];
          return StreamBuilder<List<AppCategory>>(
            key: ValueKey(_direction),
            stream: repo.watchActiveCategories(_txType),
            builder: (context, catSnap) {
              final cats = catSnap.data;
              final catItems = cats != null && cats.isNotEmpty
                  ? cats
                  : _fallbackCats(_txType, l10n);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Unparsed: show raw notification text prominently
                  if (_isUnparsed) ...[
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning_amber,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                                    size: 18),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    l10n.captureConfirmUnparsedBanner,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_capture.rawTitle?.isNotEmpty == true) ...[
                              const SizedBox(height: 8),
                              Text(
                                _capture.rawTitle!,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            SelectableText(
                              _capture.rawText,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Direction
                  SegmentedButton<CaptureDirection>(
                    segments: [
                      ButtonSegment(
                          value: CaptureDirection.expense,
                          label: Text(l10n.txTypeSpending)),
                      ButtonSegment(
                          value: CaptureDirection.income,
                          label: Text(l10n.txTypeEarning)),
                    ],
                    selected: {_direction},
                    onSelectionChanged: (s) =>
                        _onDirectionChanged(s.first),
                  ),
                  const SizedBox(height: 16),
                  // Amount
                  TextField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    decoration: InputDecoration(
                        labelText: l10n.fieldAmount, suffixText: sym),
                  ),
                  const SizedBox(height: 16),
                  // Wallet (required)
                  DropdownButtonFormField<String>(
                    initialValue: wallets.any((w) => w.id == _walletId)
                        ? _walletId
                        : null,
                    decoration:
                        InputDecoration(labelText: l10n.captureConfirmWalletField),
                    items: [
                      for (final w in wallets)
                        DropdownMenuItem(
                            value: w.id, child: Text(w.name)),
                    ],
                    onChanged: (v) => setState(() => _walletId = v),
                  ),
                  const SizedBox(height: 16),
                  // Category (optional)
                  DropdownButtonFormField<String?>(
                    initialValue: catItems.any((c) => c.id == _category)
                        ? _category
                        : null,
                    decoration:
                        InputDecoration(labelText: l10n.fieldCategory),
                    items: [
                      DropdownMenuItem<String?>(
                          value: null, child: Text(l10n.captureConfirmCategoryNone)),
                      for (final c in catItems)
                        DropdownMenuItem<String?>(
                            value: c.id, child: Text(c.label)),
                    ],
                    onChanged: (v) => setState(() => _category = v),
                  ),
                  const SizedBox(height: 16),
                  // Date
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.schedule),
                      title: Text(l10n.captureConfirmTimeLabel),
                      subtitle: Text(formatDateTime(_timestamp)),
                      trailing: TextButton(
                          onPressed: _pickDate,
                          child: Text(l10n.commonEdit)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Starred
                  SwitchListTile(
                    title: Text(l10n.commonMarkStarred),
                    value: _starred,
                    onChanged: (v) => setState(() => _starred = v),
                  ),
                  // Parsed/needsReview: raw notification text at bottom for reference
                  if (!_isUnparsed) ...[
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.captureConfirmRawContentLabel,
                              style:
                                  Theme.of(context).textTheme.labelMedium,
                            ),
                            if (_capture.rawTitle?.isNotEmpty == true) ...[
                              const SizedBox(height: 4),
                              Text(_capture.rawTitle!,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ],
                            const SizedBox(height: 4),
                            SelectableText(_capture.rawText),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : () => _confirm(wallets),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
                        : const Icon(Icons.check),
                    label: Text(l10n.captureConfirmTitle),
                  ),
                  const SizedBox(height: 80),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

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
