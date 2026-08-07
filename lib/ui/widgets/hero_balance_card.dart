import 'package:flutter/material.dart';

import '../../format.dart';
import '../../l10n/generated/app_localizations.dart';

/// Replaces the old plain "Tổng số dư" card on the Ví tab: a soft
/// primary→tertiary gradient (both derived from the user's seed color, so it
/// always harmonizes) and a count-up animation whenever [total] changes.
class HeroBalanceCard extends StatelessWidget {
  const HeroBalanceCard({super.key, required this.total});
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, Color.lerp(scheme.primary, scheme.tertiary, 0.6)!],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.walletsTotalBalance,
              style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.85), fontSize: 14)),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: total.toDouble()),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Text(
              formatVnd(value.round()),
              style: TextStyle(
                color: scheme.onPrimary,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
