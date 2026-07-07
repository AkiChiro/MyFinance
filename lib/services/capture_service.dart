import '../models/domain.dart';
import '../repositories/finance_repository.dart';
import 'bank/bank_notification_parser.dart';
import 'capture_channel.dart';
import 'permission_coordinator.dart';

/// Drains the native notification buffer, parses each item, and files
/// captures into Drift via [FinanceRepository.insertCapture].
///
/// Called on app start and on every [AppLifecycleState.resumed] event.
/// Wired in [main.dart] via [_AppLifecycleObserver].
class CaptureService {
  CaptureService({required FinanceRepository repo, required CaptureChannelApi api})
      : _repo = repo,
        _api = api;

  final FinanceRepository _repo;
  final CaptureChannelApi _api;

  PermissionCoordinator get permissions => PermissionCoordinator(_api);

  Future<List<String>> seenPackages() => _api.seenPackages();

  // Matches a money-amount shape: digits adjacent to VND, đ, or ₫.
  // Used to decide whether a null-parse notification should be filed as
  // unparsed (probable parser gap — ADR-0013) vs discarded (OTP/promo, no
  // monetary content).
  static final _rAmountShape = RegExp(
    r'(?:\d[\d.,]{2,}\s*(?:VND|đ|₫)|(?:VND|đ|₫)\s*\d[\d.,]{2,})',
    caseSensitive: false,
  );

  /// One drain cycle: set watched packages → drain → parse → file → clear.
  ///
  /// File-then-clear ordering: all inserts happen before [clearCaptures] is
  /// called, so a crash mid-drain causes a re-drain on next start rather than
  /// data loss. [insertCapture] deduplicates, so re-draining is safe.
  Future<void> drain() async {
    // 1. Compute watched packages: BankPackages.all ∪ wallet packageNames.
    final wallets = await _repo.allWallets();
    final walletPkgs = wallets
        .where((w) => w.packageName != null)
        .map((w) => w.packageName!)
        .toSet();
    final watched = {...BankPackages.all, ...walletPkgs}.toList();

    // 2. Sync watched set to native (persisted for always-on service).
    await _api.setWatchedPackages(watched);

    // 3. Drain the buffer.
    final messages = await _api.drainCaptures();
    if (messages.isEmpty) return;

    // 4. Parse and file each message.
    final allIds = <String>[];
    for (final msg in messages) {
      allIds.add(msg.id);
      final raw = RawNotification(
        packageName: msg.packageName,
        title: msg.title,
        text: msg.text,
      );
      final parser = BankParserRegistry.forPackage(msg.packageName);
      final parsed = parser?.parse(raw);
      final capturedAt =
          DateTime.fromMillisecondsSinceEpoch(msg.postTimeMillis);

      if (parsed != null) {
        // Successful parse → file with parsed fields.
        await _repo.insertCapture(
          packageName: msg.packageName,
          rawTitle: msg.title,
          rawText: msg.text,
          capturedAt: capturedAt,
          amount: parsed.amount,
          direction: parsed.direction,
          parseStatus:
              parsed.lowConfidence ? ParseStatus.needsReview : ParseStatus.parsed,
        );
      } else if (_rAmountShape.hasMatch(msg.text) ||
          (msg.title != null && _rAmountShape.hasMatch(msg.title!))) {
        // Money-shaped text but parser returned null → probable parser gap.
        // File as unparsed so no bank transaction is ever silently lost
        // (ADR-0013). insertCapture deduplicates, so re-drains are safe.
        await _repo.insertCapture(
          packageName: msg.packageName,
          rawTitle: msg.title,
          rawText: msg.text,
          capturedAt: capturedAt,
          amount: null,
          direction: null,
          parseStatus: ParseStatus.unparsed,
        );
      }
      // else: no amount shape (OTP, login alert, promo with no monetary value)
      //       → discard. The ID is still included in allIds so the native
      //         buffer is cleared — we just don't create a Drift row.
    }

    // 5. Clear acked IDs from native buffer (after all inserts complete).
    await _api.clearCaptures(allIds);
  }
}
