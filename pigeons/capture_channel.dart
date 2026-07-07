// ignore_for_file: one_member_abstracts
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/pigeon/capture_channel.g.dart',
  kotlinOut:
      'android/app/src/main/kotlin/com/huy/myfinance/pigeon/CaptureChannel.kt',
  kotlinOptions: KotlinOptions(package: 'com.huy.myfinance.pigeon'),
  dartPackageName: 'myfinance',
))

/// Single buffered notification item passed from native to Dart.
class RawCaptureMessage {
  RawCaptureMessage({
    required this.id,
    required this.packageName,
    this.title,
    required this.text,
    required this.postTimeMillis,
  });

  /// Stable UUID assigned by the native buffer on arrival.
  String id;

  /// Android package name of the notification source app.
  String packageName;

  /// Notification title — null when the notification has no title.
  String? title;

  /// Notification body text (EXTRA_BIG_TEXT preferred, EXTRA_TEXT fallback).
  String text;

  /// [notificationInfo.postTime] in milliseconds since epoch.
  int postTimeMillis;
}

/// Dart → native channel. Dart pulls; native never pushes.
@HostApi()
abstract class CaptureHostApi {
  /// Persists [packages] as the set of packages whose notifications are
  /// buffered. Replaces any previous set. Called on every drain so the watch
  /// list stays in sync even after wallets are added.
  void setWatchedPackages(List<String> packages);

  /// Returns all buffered captures without clearing the buffer.
  /// Call [clearCaptures] with their ids after Dart has filed them.
  List<RawCaptureMessage> drainCaptures();

  /// Removes the captures identified by [ids] from the native buffer.
  /// Removes by id — never blanket-overwrites — so captures that arrived
  /// during the drain window are preserved.
  void clearCaptures(List<String> ids);

  /// Returns the set of package names that have posted at least one
  /// notification since the last app install. Names only — no content.
  /// Used by the discovery surface to identify real bank package names.
  List<String> seenPackages();

  /// Returns true if this app's [NotificationListenerService] is in the
  /// system-enabled listeners list.
  bool isListenerEnabled();

  /// Deep-links to the notification listener settings screen so the user can
  /// grant or revoke access. Does not show a runtime permission dialog.
  void openListenerSettings();
}
