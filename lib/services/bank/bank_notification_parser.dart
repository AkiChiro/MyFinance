import 'mb_parser.dart';
import 'ocb_parser.dart';
import 'parsed_notification.dart';
import 'techcombank_parser.dart';

export 'parsed_notification.dart';

/// Strategy interface — one implementation per bank, keyed by package name.
abstract class BankNotificationParser {
  const BankNotificationParser();
  ParsedNotification? parse(RawNotification raw);
}

/// Android package-name constants for each supported bank.
///
/// These are best-guess identifiers.
/// TODO: verify each against a real capture once the native listener (5c) is live.
///       Cross-check: Play Store → App → id= query parameter.
class BankPackages {
  // TODO: verify against a real capture / Play Store id=com.ocb.app
  static const ocb = 'com.ocb.app';
  // TODO: verify against a real capture / Play Store id=com.mbmobile
  static const mb = 'com.mbmobile';
  // TODO: verify against a real capture / Play Store id=com.techcombank.mb
  static const techcombank = 'com.techcombank.mb';

  /// All known bank package names — used by [CaptureService] to build the
  /// watched-packages set on every drain.
  static const List<String> all = [ocb, mb, techcombank];
}

/// Returns the correct [BankNotificationParser] for a given package name,
/// or null if the package is not a supported bank.
class BankParserRegistry {
  static const _parsers = <String, BankNotificationParser>{
    BankPackages.ocb: OcbParser(),
    BankPackages.mb: MbParser(),
    BankPackages.techcombank: TechcombankParser(),
  };

  static BankNotificationParser? forPackage(String packageName) =>
      _parsers[packageName];
}
