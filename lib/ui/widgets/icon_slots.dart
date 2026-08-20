import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// All customizable icon slot ids. Every other icon in the app stays a plain
/// built-in `Icon` — only these are user-overridable (see `AppIcon`).
const kIconSlots = [
  'nav_wallets', 'nav_transactions', 'nav_analytics', 'nav_settings',
  'fab_add',
  'type_spending', 'type_earning', 'type_transfer',
  'star',
  'wallet_cash', 'wallet_bank',
];

/// Groups slots for the "Biểu tượng" settings section, in display order.
const kIconSlotGroups = <String, List<String>>{
  'nav': ['nav_wallets', 'nav_transactions', 'nav_analytics', 'nav_settings'],
  'fab': ['fab_add'],
  'type': ['type_spending', 'type_earning', 'type_transfer'],
  'star': ['star'],
  'wallet': ['wallet_cash', 'wallet_bank'],
};

String iconSlotGroupTitle(AppLocalizations l10n, String groupId) => switch (groupId) {
      'nav' => l10n.themeIconGroupNav,
      'fab' => l10n.themeIconGroupFab,
      'type' => l10n.themeIconGroupType,
      'star' => l10n.themeIconGroupStar,
      'wallet' => l10n.themeIconGroupWallet,
      _ => groupId,
    };

String iconSlotDisplayName(AppLocalizations l10n, String slotId) => switch (slotId) {
      'nav_wallets' => l10n.themeIconSlotNavWallets,
      'nav_transactions' => l10n.themeIconSlotNavTransactions,
      'nav_analytics' => l10n.themeIconSlotNavAnalytics,
      'nav_settings' => l10n.themeIconSlotNavSettings,
      'fab_add' => l10n.themeIconSlotFabAdd,
      'type_spending' => l10n.themeIconSlotTypeSpending,
      'type_earning' => l10n.themeIconSlotTypeEarning,
      'type_transfer' => l10n.themeIconSlotTypeTransfer,
      'star' => l10n.themeIconSlotStar,
      'wallet_cash' => l10n.themeIconSlotWalletCash,
      'wallet_bank' => l10n.themeIconSlotWalletBank,
      _ => slotId,
    };

/// The built-in Material icon each slot falls back to when no custom image
/// is set. Used by the settings thumbnail preview; individual screens pass
/// their own `fallback:` explicitly (some slots render more than one visual
/// state, e.g. nav icons have outlined/filled variants).
IconData iconSlotFallback(String slotId) => switch (slotId) {
      'nav_wallets' => Icons.account_balance_wallet_outlined,
      'nav_transactions' => Icons.receipt_long_outlined,
      'nav_analytics' => Icons.bar_chart_outlined,
      'nav_settings' => Icons.settings_outlined,
      'fab_add' => Icons.add,
      'type_spending' => Icons.south_west,
      'type_earning' => Icons.north_east,
      'type_transfer' => Icons.swap_horiz,
      'star' => Icons.star,
      'wallet_cash' => Icons.payments_outlined,
      'wallet_bank' => Icons.account_balance_outlined,
      _ => Icons.help_outline,
    };
