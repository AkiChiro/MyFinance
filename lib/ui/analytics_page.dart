import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../format.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/domain.dart';
import '../providers.dart';
import '../repositories/finance_repository.dart';
import 'category_colors.dart';
import 'widgets/app_icon.dart';

// ---------------------------------------------------------------------------
// Analytics data holder
// ---------------------------------------------------------------------------
class _Stats {
  final int spending;
  final int earning;
  final int prevSpending;
  final int prevEarning;
  final Map<String, int> spendByCat;
  final Map<String, int> earnByCat;
  final int yearSpending;
  final int yearEarning;

  const _Stats({
    required this.spending,
    required this.earning,
    required this.prevSpending,
    required this.prevEarning,
    required this.spendByCat,
    required this.earnByCat,
    required this.yearSpending,
    required this.yearEarning,
  });

  int get net => earning - spending;
  int get prevNet => prevEarning - prevSpending;
  int get yearNet => yearEarning - yearSpending;

  factory _Stats.fromBundle(AnalyticsBundle b) => _Stats(
        spending: b.currSpending,
        earning: b.currEarning,
        prevSpending: b.prevSpending,
        prevEarning: b.prevEarning,
        spendByCat: b.spendByCat,
        earnByCat: b.earnByCat,
        yearSpending: b.yearSpending,
        yearEarning: b.yearEarning,
      );
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------
class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  late DateTime _month;
  late Stream<AnalyticsBundle> _bundleStream;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _bundleStream =
        ref.read(repositoryProvider).watchAnalyticsBundle(_month);
  }

  void _prevMonth() => setState(() {
        _month = DateTime(_month.year, _month.month - 1);
        _bundleStream =
            ref.read(repositoryProvider).watchAnalyticsBundle(_month);
      });

  void _nextMonth() {
    final next = DateTime(_month.year, _month.month + 1);
    if (!next.isAfter(DateTime.now())) {
      setState(() {
        _month = next;
        _bundleStream =
            ref.read(repositoryProvider).watchAnalyticsBundle(next);
      });
    }
  }

  /// Switches to Giao dịch pre-filtered to match what was tapped here —
  /// same type, same category (if any), and scoped to the month currently
  /// shown so the landed list sums to the figure that was tapped.
  void _drillDown({required String type, String? category}) {
    ref.read(txnTypeFilterProvider.notifier).state = type;
    ref.read(txnCategoryFilterProvider.notifier).state = category;
    ref.read(txnStarredOnlyProvider.notifier).state = false;
    ref.read(monthModeProvider.notifier).state = true;
    ref.read(selectedMonthProvider.notifier).state = _month;
    ref.read(homeTabIndexProvider.notifier).state = 1; // Giao dịch tab
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repositoryProvider);
    return StreamBuilder<List<AppCategory>>(
      stream: repo.watchAllCategories(),
      builder: (context, catSnap) {
        final catLabels = {
          for (final c in catSnap.data ?? const <AppCategory>[]) c.id: c.label
        };
        return StreamBuilder<AnalyticsBundle>(
          stream: _bundleStream,
          builder: (context, snap) {
            final bundle = snap.data;
            if (bundle == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final s = _Stats.fromBundle(bundle);
            final l10n = AppLocalizations.of(context)!;

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _MonthPicker(month: _month, onPrev: _prevMonth, onNext: _nextMonth),
                const SizedBox(height: 12),
                _SummaryCards(
                  stats: s,
                  onTotalTap: (type) => _drillDown(type: type),
                ),
                const SizedBox(height: 16),
                _BarSection(stats: s, month: _month),
                const SizedBox(height: 16),
                if (s.spendByCat.isNotEmpty) ...[
                  _PieSection(
                    title: l10n.analyticsSpendByCategoryTitle,
                    data: s.spendByCat,
                    total: s.spending,
                    colorOf: spendColor,
                    catLabels: catLabels,
                    onSliceTap: (category) =>
                        _drillDown(type: TxTypes.spending, category: category),
                  ),
                  const SizedBox(height: 16),
                ],
                _EnvelopeSection(
                  categories: catSnap.data ?? const <AppCategory>[],
                  onRowTap: (category) =>
                      _drillDown(type: TxTypes.spending, category: category),
                ),
                const SizedBox(height: 16),
                if (s.earnByCat.isNotEmpty) ...[
                  _PieSection(
                    title: l10n.analyticsEarnByCategoryTitle,
                    data: s.earnByCat,
                    total: s.earning,
                    colorOf: earnColor,
                    catLabels: catLabels,
                    onSliceTap: (category) =>
                        _drillDown(type: TxTypes.earning, category: category),
                  ),
                  const SizedBox(height: 16),
                ],
                _YearCard(stats: s, year: _month.year),
                const SizedBox(height: 80),
              ],
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Month picker row
// ---------------------------------------------------------------------------
class _MonthPicker extends StatelessWidget {
  const _MonthPicker(
      {required this.month, required this.onPrev, required this.onNext});
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isCurrentMonth = month.year == DateTime.now().year &&
        month.month == DateTime.now().month;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
            icon: const Icon(Icons.chevron_left), onPressed: onPrev),
        Text(
          formatMonth(month),
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: isCurrentMonth ? null : onNext,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Summary cards
// ---------------------------------------------------------------------------
class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.stats, required this.onTotalTap});
  final _Stats stats;
  final void Function(String type) onTotalTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final net = stats.net;
    final netColor =
        net >= 0 ? Colors.green.shade700 : Theme.of(context).colorScheme.error;
    return Column(
      children: [
        Row(
          children: [
            _StatCard(
              label: l10n.analyticsTotalSpending,
              value: formatVnd(stats.spending),
              color: Theme.of(context).colorScheme.error,
              icon: AppIcon('type_spending',
                  fallback: Icons.south_west,
                  size: 16,
                  color: Theme.of(context).colorScheme.error),
              pct: _pct(stats.spending, stats.prevSpending),
              onTap: () => onTotalTap(TxTypes.spending),
            ),
            const SizedBox(width: 8),
            _StatCard(
              label: l10n.analyticsTotalEarning,
              value: formatVnd(stats.earning),
              color: Colors.green.shade700,
              icon: AppIcon('type_earning',
                  fallback: Icons.north_east,
                  size: 16,
                  color: Colors.green.shade700),
              pct: _pct(stats.earning, stats.prevEarning),
              onTap: () => onTotalTap(TxTypes.earning),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: Icon(
              net >= 0 ? Icons.trending_up : Icons.trending_down,
              color: netColor,
            ),
            title: Text(l10n.analyticsNetThisMonth),
            trailing: Text(
              (net >= 0 ? '+' : '') + formatVnd(net),
              style:
                  TextStyle(color: netColor, fontWeight: FontWeight.bold),
            ),
            subtitle: stats.prevNet != 0
                ? Text(
                    l10n.analyticsNetComparisonLabel(
                        _signedPctStr(_pct(net, stats.prevNet)!)),
                    style: TextStyle(
                        color: (net >= stats.prevNet
                            ? Colors.green.shade700
                            : Theme.of(context).colorScheme.error)),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  double? _pct(int curr, int prev) {
    if (prev == 0) return null;
    return (curr - prev) / prev * 100;
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.pct,
    this.onTap,
  });
  final String label;
  final String value;
  final Color color;
  final Widget icon;
  final double? pct;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Expanded(
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16), // matches main.dart's global CardThemeData shape
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    icon,
                    const SizedBox(width: 4),
                    Text(label,
                        style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                if (pct != null)
                  Text(l10n.analyticsPctSuffix(_signedPctStr(pct!)),
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _signedPctStr(double pct) =>
    '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%';

// ---------------------------------------------------------------------------
// Bar chart — this month vs previous month
// ---------------------------------------------------------------------------
class _BarSection extends StatelessWidget {
  const _BarSection({required this.stats, required this.month});
  final _Stats stats;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final prev = DateTime(month.year, month.month - 1);
    final maxY = [
          stats.spending.toDouble(),
          stats.earning.toDouble(),
          stats.prevSpending.toDouble(),
          stats.prevEarning.toDouble(),
        ].fold(0.0, (a, b) => a > b ? a : b) *
        1.15;

    if (maxY == 0) {
      return Card(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: Text(l10n.analyticsNoData))));
    }

    final errorColor = Theme.of(context).colorScheme.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Text(l10n.analyticsMonthComparisonTitle,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            Row(
              children: [
                _LegendDot(color: errorColor.withValues(alpha: 0.5),
                    label: l10n.spendingLegendLabel(formatMonth(prev))),
                const SizedBox(width: 12),
                _LegendDot(color: errorColor,
                    label: l10n.spendingLegendLabel(formatMonth(month))),
                const SizedBox(width: 12),
                _LegendDot(
                    color: Colors.green.shade300,
                    label: l10n.earningLegendLabel(formatMonth(prev))),
                const SizedBox(width: 12),
                _LegendDot(
                    color: Colors.green.shade700,
                    label: l10n.earningLegendLabel(formatMonth(month))),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barsSpace: 4,
                      barRods: [
                        BarChartRodData(
                            toY: stats.prevSpending.toDouble(),
                            color: errorColor.withValues(alpha: 0.5),
                            width: 20,
                            borderRadius: BorderRadius.circular(4)),
                        BarChartRodData(
                            toY: stats.spending.toDouble(),
                            color: errorColor,
                            width: 20,
                            borderRadius: BorderRadius.circular(4)),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barsSpace: 4,
                      barRods: [
                        BarChartRodData(
                            toY: stats.prevEarning.toDouble(),
                            color: Colors.green.shade300,
                            width: 20,
                            borderRadius: BorderRadius.circular(4)),
                        BarChartRodData(
                            toY: stats.earning.toDouble(),
                            color: Colors.green.shade700,
                            width: 20,
                            borderRadius: BorderRadius.circular(4)),
                      ],
                    ),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) => Text(
                          v == 0 ? l10n.txTypeSpending : l10n.txTypeEarning,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIdx, rod, rodIdx) {
                        return BarTooltipItem(
                          formatVnd(rod.toY.toInt()),
                          const TextStyle(
                              color: Colors.white, fontSize: 11),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 9)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pie chart section
// ---------------------------------------------------------------------------
class _PieSection extends StatefulWidget {
  const _PieSection({
    required this.title,
    required this.data,
    required this.total,
    required this.colorOf,
    required this.catLabels,
    this.onSliceTap,
  });
  final String title;
  final Map<String, int> data;
  final int total;
  final Color Function(String) colorOf;
  final Map<String, String> catLabels;
  final void Function(String categoryId)? onSliceTap;

  @override
  State<_PieSection> createState() => _PieSectionState();
}

class _PieSectionState extends State<_PieSection> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entries = widget.data.entries.toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          if (event is FlTapUpEvent) {
                            final idx =
                                response?.touchedSection?.touchedSectionIndex;
                            if (idx != null && idx >= 0 && idx < entries.length) {
                              widget.onSliceTap?.call(entries[idx].key);
                            }
                          }
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                response == null ||
                                response.touchedSection == null) {
                              _touched = -1;
                              return;
                            }
                            _touched = response
                                .touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      sections: List.generate(entries.length, (i) {
                        final e = entries[i];
                        final pct = widget.total > 0
                            ? e.value / widget.total * 100
                            : 0.0;
                        final isTouched = i == _touched;
                        return PieChartSectionData(
                          value: e.value.toDouble(),
                          color: widget.colorOf(e.key),
                          radius: isTouched ? 65 : 55,
                          title:
                              '${pct.toStringAsFixed(1)}%',
                          titleStyle: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        );
                      }),
                      sectionsSpace: 2,
                      centerSpaceRadius: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: entries.map((e) {
                      return InkWell(
                        onTap: widget.onSliceTap == null
                            ? null
                            : () => widget.onSliceTap!(e.key),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    color: widget.colorOf(e.key),
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  widget.catLabels[e.key] ??
                                      Categories.label(l10n, e.key),
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                formatVnd(e.value),
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.analyticsCategoryTotal(formatVnd(widget.total)),
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Envelope budgeting — per-category allocation progress
// ---------------------------------------------------------------------------
//
// Unlike the rest of this page's data (_Stats/AnalyticsBundle, all month-
// scoped), envelope balances are cumulative since forever — a category's
// stack carries over month to month until spent — so this section keeps its
// own subscription rather than being folded into _Stats. Only categories
// with a currently-configured percent > 0 are shown; a 0% category has no
// budget to be "over" against, so listing it would be misleading.
class _EnvelopeSection extends ConsumerWidget {
  const _EnvelopeSection({required this.categories, required this.onRowTap});
  final List<AppCategory> categories;
  final void Function(String categoryId) onRowTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<Map<String, int>>(
      stream: repo.watchCategoryBudgetPercents(),
      builder: (context, pctSnap) {
        final percents = pctSnap.data ?? const <String, int>{};
        final budgeted = categories
            .where((c) =>
                c.kind == TxTypes.spending &&
                !c.archived &&
                (percents[c.id] ?? 0) > 0)
            .toList();
        if (budgeted.isEmpty) return const SizedBox.shrink();
        return StreamBuilder<Map<String, EnvelopeStatus>>(
          stream: repo.watchEnvelopeBalances(),
          builder: (context, envSnap) {
            final statuses =
                envSnap.data ?? const <String, EnvelopeStatus>{};
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.analyticsEnvelopeSectionTitle,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    for (final cat in budgeted)
                      _EnvelopeRow(
                        category: cat,
                        percent: percents[cat.id]!,
                        status: statuses[cat.id] ??
                            const EnvelopeStatus(allocated: 0, spent: 0),
                        onTap: () => onRowTap(cat.id),
                        onEdit: () => _showEnvelopeEditDialog(
                            context, cat, repo, percents[cat.id]!),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _EnvelopeRow extends StatelessWidget {
  const _EnvelopeRow({
    required this.category,
    required this.percent,
    required this.status,
    required this.onTap,
    required this.onEdit,
  });
  final AppCategory category;
  final int percent;
  final EnvelopeStatus status;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final color = spendColor(category.id);
    final notFunded = status.allocated == 0 && status.spent == 0;
    final over = status.spent > status.allocated;
    final ratio = notFunded
        ? 0.0
        : status.allocated > 0
            ? (status.spent / status.allocated).clamp(0.0, 1.0)
            : 1.0;
    final String caption;
    if (notFunded) {
      caption = l10n.analyticsEnvelopeNotFundedYet;
    } else if (over) {
      caption = l10n.analyticsEnvelopeOverBy(
          formatVnd(status.spent - status.allocated));
    } else {
      caption = l10n.analyticsEnvelopeRemaining(formatVnd(status.balance));
    }
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    category.label,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Text(
                  '$percent%',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor:
                    AlwaysStoppedAnimation(over ? scheme.error : color),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              style: TextStyle(
                fontSize: 12,
                color: over ? scheme.error : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showEnvelopeEditDialog(
  BuildContext context,
  AppCategory cat,
  FinanceRepository repo,
  int currentPercent,
) async {
  final l10n = AppLocalizations.of(context)!;
  final pctCtrl = TextEditingController(
      text: currentPercent > 0 ? currentPercent.toString() : '');
  String? error;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(l10n.analyticsEnvelopeEditTitle(cat.label)),
        content: TextField(
          controller: pctCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: l10n.categoriesBudgetPercentFieldOptional,
            suffixText: '%',
            errorText: error,
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmResetEnvelope(context, cat, repo);
            },
            child: Text(l10n.analyticsEnvelopeResetTrigger),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () async {
                  final percent = (int.tryParse(pctCtrl.text) ?? 0).clamp(0, 100);
                  if (percent != currentPercent) {
                    try {
                      await repo.setCategoryBudgetPercent(cat.id, percent);
                    } on BudgetPercentExceededException {
                      setDialogState(() => error = l10n.budgetPercentExceededError);
                      return;
                    }
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(l10n.commonSave),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  pctCtrl.dispose();
}

Future<void> _confirmResetEnvelope(
    BuildContext context, AppCategory cat, FinanceRepository repo) async {
  final l10n = AppLocalizations.of(context)!;
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(l10n.analyticsEnvelopeResetConfirmTitle(cat.label)),
      content: Text(l10n.analyticsEnvelopeResetConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.analyticsEnvelopeResetAction),
        ),
      ],
    ),
  );
  if (ok == true) await repo.resetEnvelope(cat.id);
}

// ---------------------------------------------------------------------------
// Year-to-date card
// ---------------------------------------------------------------------------
class _YearCard extends StatelessWidget {
  const _YearCard({required this.stats, required this.year});
  final _Stats stats;
  final int year;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final net = stats.yearNet;
    final netColor =
        net >= 0 ? Colors.green.shade700 : Theme.of(context).colorScheme.error;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.yearCardTitle(year),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _YearRow(
                label: l10n.analyticsTotalSpending,
                value: formatVnd(stats.yearSpending),
                color: Theme.of(context).colorScheme.error),
            _YearRow(
                label: l10n.analyticsTotalEarning,
                value: formatVnd(stats.yearEarning),
                color: Colors.green.shade700),
            const Divider(),
            _YearRow(
              label: l10n.analyticsNetLabel,
              value: (net >= 0 ? '+' : '') + formatVnd(net),
              color: netColor,
              bold: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _YearRow extends StatelessWidget {
  const _YearRow(
      {required this.label,
      required this.value,
      required this.color,
      this.bold = false});
  final String label;
  final String value;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }
}
