import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../format.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/domain.dart';
import '../providers.dart';
import '../services/bank/bank_notification_parser.dart';
import 'capture_confirm_page.dart';

class CapturesPage extends ConsumerWidget {
  const CapturesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.capturesTitle)),
      body: StreamBuilder<List<Wallet>>(
        stream: repo.watchWallets(),
        builder: (context, wSnap) {
          final wallets = wSnap.data ?? const [];
          final walletMap = {for (final w in wallets) w.id: w.name};
          return StreamBuilder<List<NotificationCapture>>(
            stream: repo.watchPendingCaptures(),
            builder: (context, snap) {
              final captures = snap.data ?? const [];
              if (captures.isEmpty) {
                return Center(
                  child: Text(l10n.capturesEmpty),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: captures.length,
                itemBuilder: (context, i) => _CaptureTile(
                  capture: captures[i],
                  walletMap: walletMap,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CaptureTile extends StatelessWidget {
  const _CaptureTile({required this.capture, required this.walletMap});

  final NotificationCapture capture;
  final Map<String, String> walletMap;

  static const _bankLabels = <String, String>{
    BankPackages.ocb: 'OCB',
    BankPackages.mb: 'MB',
    BankPackages.techcombank: 'Techcombank',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final (IconData icon, Color color, String statusLabel) =
        switch (capture.parseStatus) {
      ParseStatus.parsed => (
          Icons.notifications_outlined,
          scheme.primary,
          ''
        ),
      ParseStatus.needsReview => (
          Icons.help_outline,
          Colors.orange.shade700,
          l10n.capturesNeedsReview
        ),
      ParseStatus.unparsed => (
          Icons.warning_amber_outlined,
          scheme.error,
          l10n.capturesUnparsed
        ),
    };

    final walletName = capture.suggestedWalletId != null
        ? (walletMap[capture.suggestedWalletId!] ??
            _bankLabels[capture.packageName] ??
            capture.packageName)
        : (_bankLabels[capture.packageName] ?? capture.packageName);

    final amountText =
        capture.amount != null ? formatVnd(capture.amount!) : null;
    final dirSign =
        capture.direction == CaptureDirection.income ? '+' : '−';
    final amountDisplay = amountText != null ? '$dirSign$amountText' : '—';
    final amountColor = capture.direction == CaptureDirection.income
        ? Colors.green.shade700
        : (capture.amount != null ? scheme.error : null);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(walletName, overflow: TextOverflow.ellipsis),
          ),
          if (statusLabel.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                statusLabel,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: color),
              ),
            ),
        ],
      ),
      subtitle: Text(formatDateTime(capture.capturedAt)),
      trailing: Text(
        amountDisplay,
        style: TextStyle(fontWeight: FontWeight.w600, color: amountColor),
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CaptureConfirmPage(capture: capture),
      )),
    );
  }
}
