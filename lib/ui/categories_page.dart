import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../format.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/domain.dart';
import '../providers.dart';
import '../repositories/finance_repository.dart';

class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  String get _currentKind =>
      _tab.index == 0 ? TxTypes.spending : TxTypes.earning;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.categoriesTitle),
        bottom: TabBar(
          controller: _tab,
          tabs: [
            Tab(text: l10n.txTypeSpending),
            Tab(text: l10n.txTypeEarning),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _CategoryList(kind: TxTypes.spending),
          _CategoryList(kind: TxTypes.earning),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, _currentKind),
        icon: const Icon(Icons.add),
        label: Text(_tab.index == 0
            ? l10n.categoriesAddSpending
            : l10n.categoriesAddEarning),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, String kind) async {
    final repo = ref.read(repositoryProvider);
    final l10n = AppLocalizations.of(context)!;
    final labelCtrl = TextEditingController();
    final threshCtrl = TextEditingController();
    final pctCtrl = TextEditingController();
    String? error;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(kind == TxTypes.spending
              ? l10n.categoriesAddSpendingTitle
              : l10n.categoriesAddEarningTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                decoration: InputDecoration(labelText: l10n.categoriesNameField),
                autofocus: true,
              ),
              if (kind == TxTypes.spending) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: threshCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l10n.categoriesThresholdFieldOptional,
                    suffixText: '₫',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pctCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l10n.categoriesBudgetPercentFieldOptional,
                    suffixText: '%',
                    errorText: error,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
            FilledButton(
              onPressed: () async {
                final label = labelCtrl.text.trim();
                if (label.isEmpty) return;
                final threshold = int.tryParse(threshCtrl.text) ?? 0;
                final percent = (int.tryParse(pctCtrl.text) ?? 0).clamp(0, 100);
                final id = await repo.addCategory(
                    label: label, kind: kind, threshold: threshold);
                if (percent > 0) {
                  try {
                    await repo.setCategoryBudgetPercent(id, percent);
                  } on BudgetPercentExceededException {
                    setDialogState(
                        () => error = l10n.budgetPercentExceededError);
                    return;
                  }
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(l10n.commonAdd),
            ),
          ],
        ),
      ),
    );
    labelCtrl.dispose();
    threshCtrl.dispose();
    pctCtrl.dispose();
  }
}

// ── Category list ─────────────────────────────────────────────────────────────

class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<Map<String, int>>(
      stream: repo.watchCategoryBudgetPercents(),
      builder: (context, pctSnap) {
        final percents = pctSnap.data ?? const <String, int>{};
        return StreamBuilder<List<AppCategory>>(
          stream: repo.watchActiveCategories(kind),
          builder: (context, snap) {
            final cats = snap.data ?? [];
            if (cats.isEmpty) {
              return Center(
                child: Text(
                  kind == TxTypes.spending
                      ? l10n.categoriesEmptySpending
                      : l10n.categoriesEmptyEarning,
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
              children: [
                for (final cat in cats)
                  Card(
                    child: ListTile(
                      title: Text(cat.label),
                      subtitle: Text([
                        if (cat.threshold > 0)
                          l10n.categoriesThresholdSubtitle(formatVnd(cat.threshold))
                        else
                          l10n.categoriesNoThreshold,
                        if (kind == TxTypes.spending && (percents[cat.id] ?? 0) > 0)
                          l10n.categoriesBudgetPercentSubtitle(percents[cat.id]!),
                      ].join(' · ')),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _showEditDialog(
                                context, cat, repo, percents[cat.id] ?? 0),
                          ),
                          IconButton(
                            icon: const Icon(Icons.archive_outlined),
                            tooltip: l10n.categoriesArchiveTooltip,
                            onPressed: () => _confirmArchive(context, cat, repo),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditDialog(BuildContext context, AppCategory cat,
      FinanceRepository repo, int currentPercent) async {
    final l10n = AppLocalizations.of(context)!;
    final labelCtrl = TextEditingController(text: cat.label);
    final threshCtrl = TextEditingController(
        text: cat.threshold > 0 ? cat.threshold.toString() : '');
    final pctCtrl = TextEditingController(
        text: currentPercent > 0 ? currentPercent.toString() : '');
    String? error;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.categoriesEditTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                decoration: InputDecoration(labelText: l10n.categoriesNameField),
                autofocus: true,
              ),
              if (cat.kind == TxTypes.spending) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: threshCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l10n.categoriesThresholdFieldEdit,
                    suffixText: '₫',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pctCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l10n.categoriesBudgetPercentFieldOptional,
                    suffixText: '%',
                    errorText: error,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.commonCancel)),
            FilledButton(
              onPressed: () async {
                final percent = (int.tryParse(pctCtrl.text) ?? 0).clamp(0, 100);
                if (percent != currentPercent) {
                  try {
                    await repo.setCategoryBudgetPercent(cat.id, percent);
                  } on BudgetPercentExceededException {
                    setDialogState(
                        () => error = l10n.budgetPercentExceededError);
                    return;
                  }
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      final label = labelCtrl.text.trim();
      if (label.isEmpty) return;
      final threshold = int.tryParse(threshCtrl.text) ?? 0;
      await repo.updateCategory(
        AppCategory(
          id: cat.id,
          label: label,
          kind: cat.kind,
          threshold: threshold,
          isDefault: cat.isDefault,
          archived: cat.archived,
          sortOrder: cat.sortOrder,
        ),
      );
    }
    labelCtrl.dispose();
    threshCtrl.dispose();
    pctCtrl.dispose();
  }

  Future<void> _confirmArchive(
      BuildContext context, AppCategory cat, FinanceRepository repo) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.categoriesArchiveConfirmTitle(cat.label)),
        content: Text(l10n.categoriesArchiveConfirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.categoriesArchiveConfirmAction)),
        ],
      ),
    );
    if (ok == true) await repo.archiveCategory(cat.id);
  }
}
