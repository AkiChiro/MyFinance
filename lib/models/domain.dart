// Domain enums. Stored in the DB as plain strings.
// Category IDs ('necessities', 'food', …) are stable keys seeded into the
// AppCategories table on first run. The label() helpers here act as
// locale-aware fallbacks when the DB hasn't loaded yet — they take a
// resolved AppLocalizations instance rather than a BuildContext, so this
// file stays free of Flutter widget imports.

import '../l10n/generated/app_localizations.dart';

class TxTypes {
  static const spending = 'spending';
  static const earning = 'earning';
  static const transfer = 'transfer';

  static String label(AppLocalizations l10n, String type) => switch (type) {
        spending => l10n.txTypeSpending,
        earning => l10n.txTypeEarning,
        transfer => l10n.txTypeTransfer,
        _ => type,
      };
}

/// Default category metadata — mirrors what is seeded into AppCategories.
/// UI should prefer reading live data from the DB; use these as fallbacks.
class Categories {
  static const spending = ['necessities', 'food', 'hobbies', 'others'];
  static const earning = ['provided', 'self_earned', 'others_earn'];

  /// Default auto-star thresholds (VND) for each seeded spending category.
  static const defaultThresholds = {
    'necessities': 500000,
    'food': 100000,
    'hobbies': 1000000,
    'others': 200000,
  };

  static List<String> forType(String txType) =>
      txType == TxTypes.earning ? earning : spending;

  static String fallbackFor(String txType) =>
      txType == TxTypes.earning ? 'others_earn' : 'others';

  static String label(AppLocalizations l10n, String? id) => switch (id) {
        null => '—',
        'necessities' => l10n.categoryNecessities,
        'food' => l10n.categoryFood,
        'hobbies' => l10n.categoryHobbies,
        'others' || 'others_earn' => l10n.categoryOthers,
        'provided' => l10n.categoryProvided,
        'self_earned' => l10n.categorySelfEarned,
        _ => id,
      };
}

class WalletKinds {
  static const cash = 'cash';
  static const bank = 'bank';
  static String label(AppLocalizations l10n, String id) => switch (id) {
        cash => l10n.walletKindCash,
        bank => l10n.walletKindBank,
        _ => id,
      };
}

// Append-only: stored by name (textEnum). Never reorder, remove, or rename.
enum SourceType { manual, csvImport, bankNotification }

// Append-only: stored by name (textEnum). Never reorder, remove, or rename.
enum CaptureDirection { income, expense }

// Append-only: stored by name (textEnum). Never reorder, remove, or rename.
enum ParseStatus { parsed, needsReview, unparsed }

// Append-only: stored by name (textEnum). Never reorder, remove, or rename.
enum CaptureStatus { pending, confirmed, dismissed }

enum CsvImportMode { contextOnly, reconstructBalance }
