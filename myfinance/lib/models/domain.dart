// Domain enums + Vietnamese labels. Stored in the DB as plain strings.

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

/// Category ids are unique across both groups so they never collide in the DB.
/// (earning "Others" is `others_earn` to stay distinct from spending "Others").
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

  static List<String> forType(String txType) =>
      txType == TxTypes.earning ? earning : spending;

  /// Default fallback category for a given transaction type.
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
