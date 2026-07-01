// Domain enums + Vietnamese labels. Stored in the DB as plain strings.
// Category IDs ('necessities', 'food', …) are stable keys seeded into the
// AppCategories table on first run. The static helpers here act as fallbacks
// when the DB hasn't loaded yet.

class TxTypes {
  static const spending = 'spending';
  static const earning = 'earning';
  static const transfer = 'transfer';

  static const labels = {
    spending: 'Chi tiêu',
    earning: 'Thu nhập',
    transfer: 'Chuyển khoản',
  };
}

/// Default category metadata — mirrors what is seeded into AppCategories.
/// UI should prefer reading live data from the DB; use these as fallbacks.
class Categories {
  static const spending = ['necessities', 'food', 'hobbies', 'others'];
  static const earning = ['provided', 'self_earned', 'others_earn'];

  static const labels = {
    'necessities': 'Thiết yếu',
    'food': 'Ăn uống',
    'hobbies': 'Sở thích',
    'others': 'Khác',
    'provided': 'Chu cấp',
    'self_earned': 'Tự kiếm',
    'others_earn': 'Khác',
  };

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

  static String label(String? id) => id == null ? '—' : (labels[id] ?? id);
}

class WalletKinds {
  static const cash = 'cash';
  static const bank = 'bank';
  static const labels = {cash: 'Tiền mặt', bank: 'Ngân hàng'};
  static String label(String id) => labels[id] ?? id;
}
