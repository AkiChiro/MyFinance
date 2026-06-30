import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/database.dart';
import '../format.dart';
import '../main.dart' show repository;
import '../models/domain.dart';

// ---------------------------------------------------------------------------
// Category colours
// ---------------------------------------------------------------------------
const _spendColors = <String, Color>{
  'necessities': Color(0xFFFF7043),
  'food': Color(0xFFFFCA28),
  'hobbies': Color(0xFF7E57C2),
  'others': Color(0xFF78909C),
};
const _earnColors = <String, Color>{
  'provided': Color(0xFF66BB6A),
  'self_earned': Color(0xFF42A5F5),
  'others_earn': Color(0xFF78909C),
};

Color _spendColor(String cat) => _spendColors[cat] ?? const Color(0xFF78909C);
Color _earnColor(String cat) => _earnColors[cat] ?? const Color(0xFF78909C);

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

  static _Stats fromTxns(List<Txn> txns, DateTime month) {
    final prev = DateTime(month.year, month.month - 1);
    int sp = 0, ea = 0, psp = 0, pea = 0, ysp = 0, yea = 0;
    final scat = <String, int>{};
    final ecat = <String, int>{};

    for (final t in txns) {
      if (t.imported) continue;
      if (t.type == TxTypes.transfer) continue;

      final inCurr =
          t.timestamp.year == month.year && t.timestamp.month == month.month;
      final inPrev =
          t.timestamp.year == prev.year && t.timestamp.month == prev.month;
      final inYear = t.timestamp.year == month.year;

      if (t.type == TxTypes.spending) {
        if (inCurr) {
          sp += t.amount;
          final cat = t.category ?? 'others';
          scat[cat] = (scat[cat] ?? 0) + t.amount;
        }
        if (inPrev) psp += t.amount;
        if (inYear) ysp += t.amount;
      } else if (t.type == TxTypes.earning) {
        if (inCurr) {
          ea += t.amount;
          final cat = t.category ?? 'others_earn';
          ecat[cat] = (ecat[cat] ?? 0) + t.amount;
        }
        if (inPrev) pea += t.amount;
        if (inYear) yea += t.amount;
      }
    }

    return _Stats(
      spending: sp,
      earning: ea,
      prevSpending: psp,
      prevEarning: pea,
      spendByCat: scat,
      earnByCat: ecat,
      yearSpending: ysp,
      yearEarning: yea,
    );
  }
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _prevMonth() =>
      setState(() => _month = DateTime(_month.year, _month.month - 1));
  void _nextMonth() {
    final next = DateTime(_month.year, _month.month + 1);
    if (!next.isAfter(DateTime.now())) setState(() => _month = next);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Txn>>(
      stream: repository.watchTxns(),
      builder: (context, snap) {
        final txns = snap.data ?? const [];
        final s = _Stats.fromTxns(txns, _month);

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _MonthPicker(month: _month, onPrev: _prevMonth, onNext: _nextMonth),
            const SizedBox(height: 12),
            _SummaryCards(stats: s),
            const SizedBox(height: 16),
            _BarSection(stats: s, month: _month),
            const SizedBox(height: 16),
            if (s.spendByCat.isNotEmpty) ...[
              _PieSection(
                title: 'Chi tiêu theo danh mục',
                data: s.spendByCat,
                total: s.spending,
                colorOf: _spendColor,
              ),
              const SizedBox(height: 16),
            ],
            if (s.earnByCat.isNotEmpty) ...[
              _PieSection(
                title: 'Thu nhập theo danh mục',
                data: s.earnByCat,
                total: s.earning,
                colorOf: _earnColor,
              ),
              const SizedBox(height: 16),
            ],
            _YearCard(stats: s, year: _month.year),
            const SizedBox(height: 80),
          ],
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
  const _SummaryCards({required this.stats});
  final _Stats stats;

  @override
  Widget build(BuildContext context) {
    final net = stats.net;
    final netColor =
        net >= 0 ? Colors.green.shade700 : Theme.of(context).colorScheme.error;
    return Column(
      children: [
        Row(
          children: [
            _StatCard(
              label: 'Tổng chi',
              value: formatVnd(stats.spending),
              color: Theme.of(context).colorScheme.error,
              icon: Icons.south_west,
              pct: _pct(stats.spending, stats.prevSpending),
            ),
            const SizedBox(width: 8),
            _StatCard(
              label: 'Tổng thu',
              value: formatVnd(stats.earning),
              color: Colors.green.shade700,
              icon: Icons.north_east,
              pct: _pct(stats.earning, stats.prevEarning),
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
            title: const Text('Chênh lệch tháng này'),
            trailing: Text(
              (net >= 0 ? '+' : '') + formatVnd(net),
              style:
                  TextStyle(color: netColor, fontWeight: FontWeight.bold),
            ),
            subtitle: stats.prevNet != 0
                ? Text(
                    'So tháng trước: ${_pctStr(_pct(net, stats.prevNet))}',
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
  });
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final double? pct;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
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
                Text(_pctStr(pct),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

String _pctStr(double? pct) {
  if (pct == null) return '';
  final sign = pct >= 0 ? '+' : '';
  return '$sign${pct.toStringAsFixed(1)}% so tháng trước';
}

// ---------------------------------------------------------------------------
// Bar chart — this month vs previous month
// ---------------------------------------------------------------------------
class _BarSection extends StatelessWidget {
  const _BarSection({required this.stats, required this.month});
  final _Stats stats;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final prev = DateTime(month.year, month.month - 1);
    final maxY = [
          stats.spending.toDouble(),
          stats.earning.toDouble(),
          stats.prevSpending.toDouble(),
          stats.prevEarning.toDouble(),
        ].fold(0.0, (a, b) => a > b ? a : b) *
        1.15;

    if (maxY == 0) {
      return const Card(
          child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('Chưa có dữ liệu.'))));
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
              child: Text('So sánh tháng',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            Row(
              children: [
                _LegendDot(color: errorColor.withValues(alpha: 0.5),
                    label: 'Chi (${formatMonth(prev)})'),
                const SizedBox(width: 12),
                _LegendDot(color: errorColor, label: 'Chi (${formatMonth(month)})'),
                const SizedBox(width: 12),
                _LegendDot(
                    color: Colors.green.shade300,
                    label: 'Thu (${formatMonth(prev)})'),
                const SizedBox(width: 12),
                _LegendDot(
                    color: Colors.green.shade700,
                    label: 'Thu (${formatMonth(month)})'),
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
                          v == 0 ? 'Chi tiêu' : 'Thu nhập',
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
  });
  final String title;
  final Map<String, int> data;
  final int total;
  final Color Function(String) colorOf;

  @override
  State<_PieSection> createState() => _PieSectionState();
}

class _PieSectionState extends State<_PieSection> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
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
                      final pct = widget.total > 0
                          ? e.value / widget.total * 100
                          : 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
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
                                Categories.label(e.key),
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${pct.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Tổng: ${formatVnd(widget.total)}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
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
    final net = stats.yearNet;
    final netColor =
        net >= 0 ? Colors.green.shade700 : Theme.of(context).colorScheme.error;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Năm $year',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _YearRow(
                label: 'Tổng chi',
                value: formatVnd(stats.yearSpending),
                color: Theme.of(context).colorScheme.error),
            _YearRow(
                label: 'Tổng thu',
                value: formatVnd(stats.yearEarning),
                color: Colors.green.shade700),
            const Divider(),
            _YearRow(
              label: 'Chênh lệch',
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
