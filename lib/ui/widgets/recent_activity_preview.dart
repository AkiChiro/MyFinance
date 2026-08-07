import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../format.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/domain.dart';
import '../../providers.dart';
import '../category_colors.dart';

const _kPreviewLimit = 5;

/// A glance card above the wallet list: a trend sparkline plus the last few
/// transactions. Slices the existing `watchTxns()` stream client-side rather
/// than adding a dedicated bounded query — dataset sizes here are trivially
/// small for a single-user offline app. Hides entirely once there is no
/// activity yet (the empty-wallets state already guides new users).
class RecentActivityPreview extends ConsumerWidget {
  const RecentActivityPreview({super.key, required this.walletMap});
  final Map<String, String> walletMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    final settings = ref.watch(settingsProvider);
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<List<Txn>>(
      stream: repo.watchTxns(),
      builder: (context, snap) {
        final all = snap.data ?? const [];
        if (all.isEmpty) return const SizedBox.shrink();
        final recent = all.take(_kPreviewLimit).toList();
        final trend = _trendOf(recent);

        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.walletsRecentActivityTitle,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.outline),
                    children: [
                      TextSpan(
                          text: l10n.walletsRecentActivitySubtitle(recent.length)),
                      const TextSpan(text: '  ·  '),
                      TextSpan(
                        text: formatSigned(trend.netChange.abs(),
                            negative: trend.netChange < 0,
                            symbol: settings.currencySymbol,
                            suffix: settings.currencySuffix),
                        style: TextStyle(
                          color: _trendColor(context, trend.netChange),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                _TrendSparkline(trend: trend),
                const Divider(height: 16),
                for (final t in recent)
                  _RecentTile(txn: t, walletMap: walletMap, l10n: l10n),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Cumulative signed-amount running total, oldest→newest, plus the final net
/// change. Transfers move money between the user's own wallets — net zero on
/// overall balance, so they don't move the trend line.
class _Trend {
  const _Trend(this.spots, this.netChange);
  final List<FlSpot> spots;
  final int netChange;
}

_Trend _trendOf(List<Txn> newestFirst) {
  final oldestFirst = newestFirst.reversed.toList();
  var running = 0;
  final spots = <FlSpot>[];
  for (var i = 0; i < oldestFirst.length; i++) {
    running += switch (oldestFirst[i].type) {
      TxTypes.earning => oldestFirst[i].amount,
      TxTypes.spending => -oldestFirst[i].amount,
      _ => 0,
    };
    spots.add(FlSpot(i.toDouble(), running.toDouble()));
  }
  return _Trend(spots, running);
}

Color _trendColor(BuildContext context, int netChange) {
  if (netChange > 0) return Colors.green.shade700;
  if (netChange < 0) return Theme.of(context).colorScheme.error;
  return Theme.of(context).colorScheme.primary;
}

class _TrendSparkline extends StatelessWidget {
  const _TrendSparkline({required this.trend});
  final _Trend trend;

  @override
  Widget build(BuildContext context) {
    if (trend.spots.length < 2) return const SizedBox(height: 44);
    final color = _trendColor(context, trend.netChange);
    final ys = trend.spots.map((s) => s.y);
    final maxAbs = [0.0, ...ys.map((y) => y.abs())].reduce((a, b) => a > b ? a : b);
    // Pad the range so the zero reference line never sits flush on an edge.
    final pad = maxAbs == 0 ? 1.0 : maxAbs * 0.2;
    return SizedBox(
      height: 44,
      child: LineChart(
        LineChartData(
          minY: -maxAbs - pad,
          maxY: maxAbs + pad,
          titlesData: const FlTitlesData(show: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          extraLinesData: ExtraLinesData(horizontalLines: [
            HorizontalLine(
              y: 0,
              color: Theme.of(context).colorScheme.outlineVariant,
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ]),
          lineBarsData: [
            LineChartBarData(
              spots: trend.spots,
              isCurved: true,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData:
                  BarAreaData(show: true, color: color.withValues(alpha: 0.12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTile extends ConsumerWidget {
  const _RecentTile(
      {required this.txn, required this.walletMap, required this.l10n});
  final Txn txn;
  final Map<String, String> walletMap;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final scheme = Theme.of(context).colorScheme;
    final isSpending = txn.type == TxTypes.spending;
    final isTransfer = txn.type == TxTypes.transfer;

    final (IconData icon, Color color) = switch (txn.type) {
      TxTypes.spending => (Icons.south_west, spendColor(txn.category)),
      TxTypes.earning => (Icons.north_east, earnColor(txn.category)),
      _ => (Icons.swap_horiz, scheme.primary),
    };

    final title = isTransfer
        ? '${walletMap[txn.walletId] ?? txn.walletFromName ?? l10n.txnsOtherWallet} → '
            '${walletMap[txn.walletToId] ?? txn.walletToName ?? l10n.txnsOtherWallet}'
        : (txn.description?.isNotEmpty == true
            ? txn.description!
            : Categories.label(l10n, txn.category));

    final sym = settings.currencySymbol;
    final suf = settings.currencySuffix;
    final amountText = isTransfer
        ? formatMoney(txn.amount, symbol: sym, suffix: suf)
        : formatSigned(txn.amount, negative: isSpending, symbol: sym, suffix: suf);

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 18, color: color),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        amountText,
        style: TextStyle(
          color: isTransfer
              ? scheme.primary
              : (isSpending ? scheme.error : Colors.green.shade700),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
