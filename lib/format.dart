import 'package:intl/intl.dart';

final _vnd = NumberFormat.decimalPattern('vi');
final _date = DateFormat('dd/MM/yyyy HH:mm');
final _dateShort = DateFormat('dd/MM/yyyy');
final _month = DateFormat('MM/yyyy');

/// Format [amount] using the current currency settings.
/// Reads [symbol] and [suffix] from the caller so it stays a pure function
/// (no hidden globals) and testable. Both params default to the app default.
String formatMoney(
  int amount, {
  String symbol = '₫',
  bool suffix = true,
}) {
  final n = _vnd.format(amount);
  return suffix ? '$n $symbol' : '$symbol $n';
}

/// Legacy alias — kept for call-sites that haven't migrated yet.
/// Prefer [formatMoney] with explicit settings.
String formatVnd(int amount) => formatMoney(amount);

/// Signed amount for transaction lists, e.g. "-50.000 ₫" / "+1.200.000 ₫".
String formatSigned(
  int amount, {
  required bool negative,
  String symbol = '₫',
  bool suffix = true,
}) =>
    '${negative ? '-' : '+'}${formatMoney(amount.abs(), symbol: symbol, suffix: suffix)}';

String formatDateTime(DateTime t) => _date.format(t);
String formatDate(DateTime t) => _dateShort.format(t);
String formatMonth(DateTime t) => _month.format(t);

/// Parse a user-typed amount, ignoring any grouping characters they add.
int parseAmount(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 0;
  return int.tryParse(digits) ?? 0;
}

/// Parses a bank-notification amount substring to a positive integer VND.
/// Strips all non-digit characters (thousand separators `.`/`,`, currency
/// tokens `VND`/`đ`, sign `+`/`-`, and whitespace). Returns 0 for strings
/// with no digit content (malformed or separator-only input never throws).
/// Callers determine [CaptureDirection] from the `+`/`-` sign BEFORE calling
/// this — the sign is a non-digit and is stripped automatically.
/// Delegates to [parseAmount] so both paths share the same empty-string guard.
int parseVndAmount(String raw) => parseAmount(raw);
