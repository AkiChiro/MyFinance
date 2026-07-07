import '../../models/domain.dart';

/// Carries the raw notification fields from the Android listener (5c).
/// [title] is nullable — some banks (OCB, MB) put no amount-bearing content
/// in the title; Techcombank puts the amount there.
class RawNotification {
  const RawNotification({
    required this.packageName,
    this.title,
    required this.text,
  });

  final String packageName;
  final String? title;
  final String text;
}

/// Result of a successful (or partially successful) parse.
///
/// [lowConfidence] maps to [ParseStatus]:
///   false → ParseStatus.parsed (clean extraction)
///   true  → ParseStatus.needsReview (amount found but something ambiguous)
///
/// A parser returning null maps to ParseStatus.unparsed.
class ParsedNotification {
  const ParsedNotification({
    required this.amount,
    required this.direction,
    this.endingBalance,
    this.accountHint,
    this.lowConfidence = false,
  });

  final int amount;
  final CaptureDirection direction;
  final int? endingBalance;
  final String? accountHint;
  final bool lowConfidence;
}
