import '../pigeon/capture_channel.g.dart';

export '../pigeon/capture_channel.g.dart' show RawCaptureMessage;

/// Abstract interface over the Pigeon-generated [CaptureHostApi].
///
/// [CaptureService] depends on this so tests can inject a [FakeCaptureChannelApi]
/// without hitting the platform channel.
abstract class CaptureChannelApi {
  Future<void> setWatchedPackages(List<String> packages);
  Future<List<RawCaptureMessage>> drainCaptures();
  Future<void> clearCaptures(List<String> ids);
  Future<List<String>> seenPackages();
  Future<bool> isListenerEnabled();
  Future<void> openListenerSettings();
}

/// Production implementation — thin delegate to the Pigeon-generated class.
class LiveCaptureChannelApi implements CaptureChannelApi {
  final _api = CaptureHostApi();

  @override
  Future<void> setWatchedPackages(List<String> packages) =>
      _api.setWatchedPackages(packages);

  @override
  Future<List<RawCaptureMessage>> drainCaptures() => _api.drainCaptures();

  @override
  Future<void> clearCaptures(List<String> ids) => _api.clearCaptures(ids);

  @override
  Future<List<String>> seenPackages() => _api.seenPackages();

  @override
  Future<bool> isListenerEnabled() => _api.isListenerEnabled();

  @override
  Future<void> openListenerSettings() => _api.openListenerSettings();
}
