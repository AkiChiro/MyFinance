import 'package:myfinance/format.dart';
import 'package:myfinance/models/domain.dart';

import 'bank_notification_parser.dart';

/// Parser for OCB (Orient Commercial Bank) balance-change notifications.
///
/// Format: multiline body; dot-separated thousands; amount and sign on the
/// `Số tiền:` line; balance on `Số dư:` (may have a stray trailing dot);
/// account on `Tài khoản:`. Title is "Thông báo biến động số dư" (ignored).
///
/// Returns null for any notification that lacks a `Số tiền:` line — this
/// filters OTPs, promos, and other non-balance-change messages.
class OcbParser implements BankNotificationParser {
  const OcbParser();

  // Amount+sign: "Số tiền: -20.000 VND" or "+20.000 VND"
  static final _rAmount =
      RegExp(r'Số tiền:\s*([+-])([\d.,]+)\s*VND');

  // Balance: "Số dư: 335.532. VND" — ([\d.,]+) captures any trailing dot;
  // parseVndAmount strips it along with the other separators.
  static final _rBalance =
      RegExp(r'Số dư:\s*([\d.,]+)\.?\s*VND');

  static final _rAccount =
      RegExp(r'Tài khoản:\s*(\S+)');

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
