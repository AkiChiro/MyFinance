import 'package:myfinance/format.dart';
import 'package:myfinance/models/domain.dart';

import 'bank_notification_parser.dart';

/// Parser for MB (Military Commercial Joint Stock Bank) balance-change
/// notifications.
///
/// Format: single-line body, pipe-delimited fields; comma-separated thousands;
/// account in the `TK` prefix field; amount+sign in `GD:`; balance in `SD:`.
/// Example: "TK xxxxxxxx|GD: -20,000VND 07/07/26 15:25 |SD: 20,825VND|..."
///
/// Returns null for any notification that lacks a `GD:` amount field.
class MbParser implements BankNotificationParser {
  const MbParser();

  // Amount+sign: "GD: -20,000VND" — no space before VND guaranteed in samples,
  // but \s* tolerates a future spacing change between bank app versions.
  static final _rAmount = RegExp(r'GD:\s*([+-])([\d.,]+)\s*VND');

  // Balance: "SD: 20,825VND"
  static final _rBalance = RegExp(r'SD:\s*([\d.,]+)\s*VND');

  // Account: "TK xxxxxxxx|..." — stop at whitespace or pipe.
  static final _rAccount = RegExp(r'TK\s+([^\s|]+)');

  @override
  ParsedNotification? parse(RawNotification raw) {
    final amountMatch = _rAmount.firstMatch(raw.text);
    if (amountMatch == null) return null;

    final direction = amountMatch.group(1) == '+'
        ? CaptureDirection.income
        : CaptureDirection.expense;
    final amount = parseVndAmount(amountMatch.group(2)!);

    final balanceMatch = _rBalance.firstMatch(raw.text);
    final endingBalance =
        balanceMatch != null ? parseVndAmount(balanceMatch.group(1)!) : null;

    final accountHint = _rAccount.firstMatch(raw.text)?.group(1);

    return ParsedNotification(
      amount: amount,
      direction: direction,
      endingBalance: endingBalance,
      accountHint: accountHint,
    );
  }
}
