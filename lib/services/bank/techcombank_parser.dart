import 'package:myfinance/format.dart';
import 'package:myfinance/models/domain.dart';

import 'bank_notification_parser.dart';

/// Parser for Techcombank (Vietnam Technological and Commercial Joint Stock
/// Bank) balance-change notifications.
///
/// Format: amount and sign are in the TITLE (`± VND <amount>`); balance in
/// the body on `Số dư:`; account on `Tài khoản:`.
/// Income fixture title: "+ VND 20,000"
/// Expense fixture title: "- VND 20,000"
///
/// Returns null if title is absent or does not match the `± VND <amount>`
/// pattern (OTPs, promos, and login alerts carry a different title or no
/// title at all).
class TechcombankParser implements BankNotificationParser {
  const TechcombankParser();

  // Title: "+ VND 20,000" or "- VND 20,000" — \s* tolerates variable spacing.
  static final _rTitle = RegExp(r'^([+-])\s*VND\s*([\d.,]+)$');

  // Balance in body: "Số dư: VND 20,013"
  static final _rBalance = RegExp(r'Số dư:\s*VND\s*([\d.,]+)');

  static final _rAccount = RegExp(r'Tài khoản:\s*(\S+)');

  @override
  ParsedNotification? parse(RawNotification raw) {
    if (raw.title == null) return null;

    final titleMatch = _rTitle.firstMatch(raw.title!.trim());
    if (titleMatch == null) return null;

    final direction = titleMatch.group(1) == '+'
        ? CaptureDirection.income
        : CaptureDirection.expense;
    // UNVERIFIED: the expense path (title "- VND <amount>") is implemented by
    // symmetry — confirm with a real outgoing Techcombank notification.
    final amount = parseVndAmount(titleMatch.group(2)!);

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
