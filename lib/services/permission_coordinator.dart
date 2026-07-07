import 'capture_channel.dart';

/// Routes notification-listener permission for [BankCaptureService].
///
/// Notification-listener access is a special access (not a runtime permission
/// dialog): [isListenerEnabled] reads from the system-enabled-listeners list;
/// [requestListenerAccess] deep-links to the settings screen where the user
/// must manually toggle it on (ADR-0008).
class PermissionCoordinator {
  const PermissionCoordinator(this._api);

  final CaptureChannelApi _api;

  /// Returns true if [BankCaptureService] is in the enabled-listeners list.
  Future<bool> isListenerEnabled() => _api.isListenerEnabled();

  /// Opens the system notification listener settings screen.
  /// On API 30+ this jumps directly to the MyFinance entry.
  /// Does NOT show a runtime permission dialog — the user must toggle manually.
  Future<void> requestListenerAccess() => _api.openListenerSettings();
}
