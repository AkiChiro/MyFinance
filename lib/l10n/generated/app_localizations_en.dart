// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonSaveChanges => 'Save changes';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonClose => 'Close';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonMarkStarred => 'Mark starred';

  @override
  String get commonQuickAddLabel => 'Quick add';

  @override
  String commonUnexpectedError(String error) {
    return 'An error occurred: $error';
  }

  @override
  String get txTypeSpending => 'Expense';

  @override
  String get txTypeEarning => 'Income';

  @override
  String get txTypeTransfer => 'Transfer';

  @override
  String get categoryNecessities => 'Necessities';

  @override
  String get categoryFood => 'Food';

  @override
  String get categoryHobbies => 'Hobbies';

  @override
  String get categoryOthers => 'Other';

  @override
  String get categoryProvided => 'Allowance';

  @override
  String get categorySelfEarned => 'Self-earned';

  @override
  String get walletKindCash => 'Cash';

  @override
  String get walletKindBank => 'Bank';

  @override
  String get overspendError => 'Please check the actual balance';

  @override
  String get notifChannelDescription =>
      'Quick-add transaction button in the notification shade';

  @override
  String get notifBody => 'Tap to record a transaction quickly';

  @override
  String get navWallets => 'Wallets';

  @override
  String get navTransactions => 'Transactions';

  @override
  String get navAnalytics => 'Analytics';

  @override
  String get navSettings => 'Settings';

  @override
  String monthYearLabel(int month, int year) {
    return 'Month $month/$year';
  }

  @override
  String get walletsTotalBalance => 'Total balance';

  @override
  String get walletsAddButton => 'Add wallet';

  @override
  String get walletsEmptyMessage =>
      'You don\'t have any wallets yet. Create your first one to start tracking your finances!';

  @override
  String get walletsNameField => 'Wallet name';

  @override
  String get walletsCurrentBalanceField => 'Current balance (₫)';

  @override
  String get walletsBankLinkField => 'Linked bank';

  @override
  String get walletsBankLinkNone => '— None —';

  @override
  String get walletsRecentActivityTitle => 'Recent activity';

  @override
  String walletsRecentActivitySubtitle(int count) {
    return 'Over the last $count transactions';
  }

  @override
  String get walletsBankConflictTitle => 'Bank already linked';

  @override
  String walletsBankConflictBody(String name) {
    return 'This bank is already linked to wallet \"$name\". Move it to the new wallet?';
  }

  @override
  String get walletBankLinkMoveAction => 'Move';

  @override
  String get walletEditTitle => 'Edit wallet';

  @override
  String get walletEditDeleteTooltip => 'Delete wallet';

  @override
  String get walletEditNameRequired => 'Please enter a wallet name.';

  @override
  String get walletEditInitialBalanceField => 'Initial balance (₫)';

  @override
  String get walletEditBalanceHelperText =>
      'Changing this value resets the balance — old transactions will no longer count toward it.';

  @override
  String get walletEditBankLinkNoneAlt => '— Not linked —';

  @override
  String walletEditBankConflictBody(String name) {
    return 'This bank is already linked to wallet \"$name\". Move it to this wallet?';
  }

  @override
  String walletEditDeleteConfirmTitle(String name) {
    return 'Delete wallet \"$name\"?';
  }

  @override
  String get walletEditDeleteConfirmBody =>
      'Related transactions are kept but will no longer reference a wallet.';

  @override
  String get txnsChipAll => 'All';

  @override
  String get txnsChipMonth => 'Month';

  @override
  String get txnsChipStarred => 'Starred';

  @override
  String get txnsAmountAsc => 'Amount ↑';

  @override
  String get txnsAmountDesc => 'Amount ↓';

  @override
  String get txnsPickCategoryTitle => 'Choose category';

  @override
  String pendingCaptureBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bank notifications awaiting confirmation',
      one: '$count bank notification awaiting confirmation',
    );
    return '$_temp0';
  }

  @override
  String get txnsEmptyStarred => 'No starred transactions.';

  @override
  String get txnsEmptyMonth => 'No transactions this month.';

  @override
  String get txnsEmptyAll => 'No transactions yet.';

  @override
  String get txnsImportedBadge => 'imported';

  @override
  String get txnsOtherWallet => '(other wallet)';

  @override
  String get txnsUnmarkStarred => 'Unmark starred';

  @override
  String get txnsDeleteConfirmTitle => 'Delete transaction?';

  @override
  String get quickAddEditTitle => 'Edit transaction';

  @override
  String get quickAddNoWalletMessage =>
      'Add at least one wallet before recording a transaction.';

  @override
  String get fieldAmount => 'Amount';

  @override
  String get fieldDescription => 'Description';

  @override
  String get fieldCategory => 'Category';

  @override
  String get fieldWallet => 'Wallet';

  @override
  String get quickAddFromWallet => 'From wallet';

  @override
  String get quickAddToWallet => 'To wallet';

  @override
  String get quickAddTimeLabel => 'Time';

  @override
  String get quickAddInvalidAmount => 'Please enter a valid amount.';

  @override
  String get quickAddPickSourceWallet => 'Choose a source wallet.';

  @override
  String get quickAddPickWallet => 'Choose a wallet.';

  @override
  String get quickAddPickDestWallet => 'Choose a destination wallet.';

  @override
  String get quickAddSameWalletError =>
      'Source and destination wallets must be different.';

  @override
  String get analyticsNoData => 'No data yet.';

  @override
  String get analyticsMonthComparisonTitle => 'Month comparison';

  @override
  String get analyticsSpendByCategoryTitle => 'Spending by category';

  @override
  String get analyticsEarnByCategoryTitle => 'Income by category';

  @override
  String analyticsCategoryTotal(String total) {
    return 'Total: $total';
  }

  @override
  String spendingLegendLabel(String period) {
    return 'Spending ($period)';
  }

  @override
  String earningLegendLabel(String period) {
    return 'Income ($period)';
  }

  @override
  String get analyticsTotalSpending => 'Total spending';

  @override
  String get analyticsTotalEarning => 'Total income';

  @override
  String get analyticsNetThisMonth => 'Net this month';

  @override
  String analyticsPctSuffix(String signedPct) {
    return '$signedPct vs last month';
  }

  @override
  String analyticsNetComparisonLabel(String signedPct) {
    return 'Compared to last month: $signedPct vs last month';
  }

  @override
  String yearCardTitle(int year) {
    return 'Year $year';
  }

  @override
  String get analyticsNetLabel => 'Net';

  @override
  String get settingsSectionNotifications => 'Notifications';

  @override
  String get settingsSectionLanguage => 'Language';

  @override
  String get settingsSectionCurrency => 'Currency';

  @override
  String get settingsSectionAutostar => 'Auto-star';

  @override
  String get settingsSectionCategories => 'Categories';

  @override
  String get settingsSectionTheme => 'Appearance';

  @override
  String get settingsSectionCsv => 'Data backup (CSV)';

  @override
  String get settingsSectionKeywords => 'Suggestion keywords';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsSectionDeveloper => 'Developer';

  @override
  String get settingsNotifTitle => 'Persistent notification';

  @override
  String get settingsNotifSubtitle =>
      'Keep a quick-add button in the notification shade.';

  @override
  String get settingsBatteryTitle => 'Battery note';

  @override
  String get settingsBatteryBody =>
      'If the notification disappears after the screen turns off, disable \"Battery optimization\" for MyFinance in Settings → Apps.';

  @override
  String get settingsCurrencySymbolTitle => 'Currency symbol';

  @override
  String currencyExampleLabel(String symbol) {
    return 'Example: 100.000 $symbol';
  }

  @override
  String get settingsAutostarTitle => 'Auto-star by threshold';

  @override
  String get settingsAutostarSubtitle =>
      'Automatically star spending that exceeds its category threshold.';

  @override
  String get settingsManageCategoriesTitle => 'Manage categories';

  @override
  String get settingsManageCategoriesSubtitle =>
      'Add, edit, and archive spending and income categories.';

  @override
  String get settingsColorModeLabel => 'Color mode';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsAdvancedThemeTitle => 'Advanced customization';

  @override
  String get settingsAdvancedThemeSubtitle =>
      'Background color, font color, background image, theme color.';

  @override
  String get settingsCsvExportTitle => 'Export CSV';

  @override
  String get settingsCsvExportSubtitle =>
      'Share/save transactions and wallets to a CSV file.';

  @override
  String get settingsCsvShareSubject => 'MyFinance — CSV backup';

  @override
  String get settingsCsvMergeTitle => 'Import CSV (merge)';

  @override
  String get settingsCsvMergeSubtitle =>
      'Merged by id. Imported transactions are history only — they do not count toward balance or analytics.';

  @override
  String get settingsCsvReplaceTitle => 'Import CSV (replace all)';

  @override
  String get settingsCsvReplaceSubtitle =>
      'Deletes all current data and restores from CSV. Requires two files: wallets, then transactions.';

  @override
  String get settingsKeywordLibraryTitle => 'Keyword library';

  @override
  String get settingsKeywordLibrarySubtitle =>
      'Edit keywords and their suggested category for the description field.';

  @override
  String get settingsAboutSubtitle => 'Version 0.2 · Fully offline · VND only.';

  @override
  String get settingsListenerPermTitle =>
      'Grant notification-listener permission';

  @override
  String get settingsListenerPermSubtitle =>
      'Opens system settings to enable the bank-notification capture service (BankCaptureService).';

  @override
  String get settingsSeenPackagesTitle => 'Seen app packages';

  @override
  String get settingsSeenPackagesSubtitle =>
      'View package names of apps that have sent notifications — used to verify the BankPackages constants.';

  @override
  String settingsExportFailed(String error) {
    return 'CSV export failed: $error';
  }

  @override
  String get settingsImportModeTitle => 'Choose import mode';

  @override
  String get settingsImportContextOnlyTitle => 'Archive only';

  @override
  String get settingsImportContextOnlySubtitle =>
      'Does not affect wallet balances.';

  @override
  String get settingsImportReconstructTitle => 'Restore balance';

  @override
  String get settingsImportReconstructSubtitle =>
      'Counts toward balance — use only for empty wallets.';

  @override
  String csvMergeResult(int added, int skipped) {
    return 'Merged $added new transactions (skipped $skipped).';
  }

  @override
  String get settingsNonEmptyWalletError =>
      'The wallet already has balance-affecting transactions. Choose \"Archive only\" or use an empty wallet.';

  @override
  String settingsImportFailed(String error) {
    return 'CSV import failed: $error';
  }

  @override
  String get settingsReplaceConfirmTitle => 'Replace all data?';

  @override
  String get settingsReplaceConfirmBody =>
      'This will DELETE all current wallets and transactions, then restore from two CSV files (wallets + transactions).\n\nThis cannot be undone. Make sure you have a backup.';

  @override
  String get settingsReplaceConfirmAction => 'Continue';

  @override
  String get settingsPickWalletFile =>
      'Choose the wallets file (myfinance_wallets_...)';

  @override
  String get settingsPickTxnFile =>
      'Choose the transactions file (myfinance_txns_...)';

  @override
  String csvReplaceResult(int added) {
    return 'Restored $added transactions.';
  }

  @override
  String settingsRestoreFailed(String error) {
    return 'Restore failed: $error';
  }

  @override
  String get settingsNotifPermTitle => 'Notification permission needed';

  @override
  String get settingsNotifPermBody =>
      'Notification permission was permanently denied. Please grant it in the app\'s system settings.';

  @override
  String get settingsNotNow => 'Not now';

  @override
  String get settingsOpenSettings => 'Open settings';

  @override
  String get settingsCurrencySymbolFieldLabel => 'Symbol';

  @override
  String get settingsNoPackagesSeen =>
      'No packages yet. Grant notification-listener permission and wait for a bank app to send a notification.';

  @override
  String get settingsPackagesHint =>
      'Use these package names to verify BankPackages.';

  @override
  String get keywordEditorTitle => 'Suggestion keywords';

  @override
  String get keywordEditorEmpty => 'No keywords yet.';

  @override
  String get keywordEditorSaved => 'Keyword library saved.';

  @override
  String get keywordEditorAddTitle => 'Add keyword';

  @override
  String get keywordEditorKeywordField => 'Keyword';

  @override
  String get keywordEditorWeightField => 'Weight (1–10)';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get categoriesAddSpending => 'Add expense';

  @override
  String get categoriesAddEarning => 'Add income';

  @override
  String get categoriesAddSpendingTitle => 'Add spending category';

  @override
  String get categoriesAddEarningTitle => 'Add income category';

  @override
  String get categoriesNameField => 'Category name';

  @override
  String get categoriesThresholdFieldOptional =>
      'Auto-star threshold (₫, optional)';

  @override
  String get categoriesEmptySpending => 'No spending categories yet.';

  @override
  String get categoriesEmptyEarning => 'No income categories yet.';

  @override
  String categoriesThresholdSubtitle(String threshold) {
    return 'Auto-star above $threshold';
  }

  @override
  String get categoriesNoThreshold => 'No auto-star';

  @override
  String get categoriesArchiveTooltip => 'Archive category';

  @override
  String get categoriesEditTitle => 'Edit category';

  @override
  String get categoriesThresholdFieldEdit =>
      'Auto-star threshold (₫, blank = off)';

  @override
  String categoriesArchiveConfirmTitle(String label) {
    return 'Archive \"$label\"?';
  }

  @override
  String get categoriesArchiveConfirmBody =>
      'The category will be hidden from pickers, but old transactions keep it.';

  @override
  String get categoriesArchiveConfirmAction => 'Archive';

  @override
  String get themeTitle => 'Customize appearance';

  @override
  String get themeResetAction => 'Reset';

  @override
  String get themeColorsSection => 'Colors';

  @override
  String get themeSeedColorTitle => 'Theme color';

  @override
  String get themeSeedColorSubtitle =>
      'Affects buttons, the title bar, and the whole color palette.';

  @override
  String get themeBgColorTitle => 'App background color';

  @override
  String get themeBgColorSubtitle =>
      'The screen background color. \"Auto\" uses the default for light/dark mode.';

  @override
  String get themeFontColorTitle => 'Font color';

  @override
  String get themeFontColorSubtitle =>
      '\"Auto\" follows light/dark mode. Be careful with low-contrast colors.';

  @override
  String get themeBgImageSection => 'Background image';

  @override
  String get themeBgImagePickTitle => 'Choose background image';

  @override
  String get themeBgImagePickSubtitle =>
      'The image is shown behind every screen.';

  @override
  String get themeBgImageNotFound => 'Image not found';

  @override
  String get themeBgImageDeleteTitle => 'Remove background image';

  @override
  String get themeBgImageNote =>
      'When a background image is set, the app background turns transparent to show it.';

  @override
  String get themeResetConfirmTitle => 'Reset appearance?';

  @override
  String get themeResetConfirmBody =>
      'Theme color, background color, font color, background image, and custom icons will return to their defaults.';

  @override
  String get themeColorAuto => 'Auto';

  @override
  String get themeHexLabel => 'Hex color code';

  @override
  String get themeHexError => 'Invalid code (needs 6 characters)';

  @override
  String get themeIconsSection => 'Icons';

  @override
  String get themeIconsHint =>
      'Square image, transparent background. 128×128 minimum, 256×256 recommended.';

  @override
  String get themeIconGroupNav => 'Navigation';

  @override
  String get themeIconGroupFab => 'Quick-add button';

  @override
  String get themeIconGroupType => 'Transaction type';

  @override
  String get themeIconGroupStar => 'Star';

  @override
  String get themeIconGroupWallet => 'Wallet type';

  @override
  String get themeIconSlotNavWallets => 'Wallets (nav bar)';

  @override
  String get themeIconSlotNavTransactions => 'Transactions (nav bar)';

  @override
  String get themeIconSlotNavAnalytics => 'Analytics (nav bar)';

  @override
  String get themeIconSlotNavSettings => 'Settings (nav bar)';

  @override
  String get themeIconSlotFabAdd => 'Add button (FAB)';

  @override
  String get themeIconSlotTypeSpending => 'Expense icon';

  @override
  String get themeIconSlotTypeEarning => 'Income icon';

  @override
  String get themeIconSlotTypeTransfer => 'Transfer icon';

  @override
  String get themeIconSlotStar => 'Star icon';

  @override
  String get themeIconSlotWalletCash => 'Cash wallet icon';

  @override
  String get themeIconSlotWalletBank => 'Bank wallet icon';

  @override
  String get themeIconResetTooltip => 'Reset to default icon';

  @override
  String get capturesTitle => 'Bank notifications';

  @override
  String get capturesEmpty => 'No notifications to review.';

  @override
  String get capturesNeedsReview => 'Needs review';

  @override
  String get capturesUnparsed => 'Not recognized';

  @override
  String get captureConfirmManualTitle => 'Manual entry';

  @override
  String get captureConfirmTitle => 'Confirm transaction';

  @override
  String get captureConfirmDismissAction => 'Dismiss';

  @override
  String get captureConfirmUnparsedBanner =>
      'Notification could not be read automatically';

  @override
  String get captureConfirmWalletField => 'Wallet *';

  @override
  String get captureConfirmCategoryNone => '— Skip —';

  @override
  String get captureConfirmTimeLabel => 'Transaction time';

  @override
  String get captureConfirmRawContentLabel => 'Notification content';

  @override
  String get captureConfirmPickWallet => 'Please choose a wallet.';

  @override
  String get captureConfirmDismissConfirmTitle => 'Dismiss this notification?';

  @override
  String get captureConfirmDismissConfirmBody =>
      'No transaction will be created.';
}
