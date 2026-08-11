import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/database.dart';
import '../format.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/domain.dart';

const _kActionSpending = 'add_spending';
const _kActionEarning = 'add_earning';
const _kActionTransfer = 'add_transfer';
const _kActionCaptureAdd = 'capture_add';
const _kActionCaptureDismiss = 'capture_dismiss';

// v2 channel: IMPORTANCE_DEFAULT (no sound) — replaces v1 (IMPORTANCE_LOW)
// which was invisible on Vivo OriginOS and other Chinese OEM skins.
const _kChannelId = 'myfinance_quick_add_v2';
const _kNotifId = 1;

// Separate channel from the quiet persistent quick-add one: this is a
// "new item" alert, so sound/vibration stay on by default.
const _kCaptureChannelId = 'myfinance_capture_alert_v1';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  Locale _locale = const Locale('vi');

  /// Called (from main.dart, which owns the repository) when the user taps
  /// the notification body or the "Thêm" action on a capture alert. Not used
  /// for "Bỏ qua" — that's handled entirely inside the background isolate
  /// ([_onResponseBackground]) without touching the running app.
  void Function(String captureId)? onOpenCapture;

  /// Initialise the plugin and, if [enabled] is true, request POST_NOTIFICATIONS
  /// permission (Android 13+) before showing the persistent notification.
  Future<void> init({bool enabled = true, required String locale}) async {
    _locale = Locale(locale);
    const androidInit = AndroidInitializationSettings('ic_notif');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: _onResponseBackground,
    );

    if (!enabled) {
      await cancelPersistentNotification();
      return;
    }

    // Request POST_NOTIFICATIONS — permission_handler triggers the system dialog.
    final status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    }

    // Show if not permanently blocked — let the platform silently drop it if
    // the user has revoked permission rather than our code gate preventing it.
    final currentStatus = await Permission.notification.status;
    if (!currentStatus.isPermanentlyDenied) {
      await showPersistentNotification();
    }
  }

  Future<void> cancelPersistentNotification() async {
    await _plugin.cancel(_kNotifId);
  }

  /// Shows/re-shows the persistent notification. [locale] updates the
  /// remembered locale (from AppSettings); omit it to re-post in the last
  /// known locale, e.g. when an OEM dismisses the notification on tap.
  Future<void> showPersistentNotification({String? locale}) async {
    if (locale != null) _locale = Locale(locale);
    final l10n = lookupAppLocalizations(_locale);

    final androidDetails = AndroidNotificationDetails(
      _kChannelId,
      l10n.commonQuickAddLabel,
      channelDescription: l10n.notifChannelDescription,
      // IMPORTANCE_DEFAULT makes the channel visible on all OEM skins.
      // Sound and vibration are disabled so it stays non-intrusive.
      importance: Importance.defaultImportance,
      priority: Priority.low,
      playSound: false,
      enableVibration: false,
      enableLights: false,
      channelShowBadge: false,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      icon: 'ic_notif',
      actions: [
        AndroidNotificationAction(_kActionSpending, l10n.txTypeSpending,
            showsUserInterface: true),
        AndroidNotificationAction(_kActionEarning, l10n.txTypeEarning,
            showsUserInterface: true),
        AndroidNotificationAction(_kActionTransfer, l10n.txTypeTransfer,
            showsUserInterface: true),
      ],
    );

    await _plugin.show(
      _kNotifId,
      'MyFinance',
      l10n.notifBody,
      NotificationDetails(android: androidDetails),
    );
  }

  /// Pops a one-shot alert for a freshly captured bank notification. [locale]
  /// is not accepted here — callers run right after [drain], well after
  /// [init]/[showPersistentNotification] have already established [_locale].
  ///
  /// "Thêm" (showsUserInterface: true) opens the app to [onOpenCapture].
  /// "Bỏ qua" (showsUserInterface: false) never opens the app — it's routed
  /// to [_onResponseBackground], which dismisses the capture from its own
  /// isolate-local database connection.
  Future<void> showCaptureNotification(
    NotificationCapture capture, {
    String? walletName,
  }) async {
    final l10n = lookupAppLocalizations(_locale);

    final androidDetails = AndroidNotificationDetails(
      _kCaptureChannelId,
      l10n.notifCaptureChannelName,
      channelDescription: l10n.notifCaptureChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notif',
      autoCancel: true,
      actions: [
        AndroidNotificationAction(_kActionCaptureAdd, l10n.commonAdd,
            showsUserInterface: true),
        AndroidNotificationAction(
            _kActionCaptureDismiss, l10n.captureConfirmDismissAction,
            showsUserInterface: false),
      ],
    );

    await _plugin.show(
      // Each capture gets its own notification id so several arriving in one
      // drain cycle don't overwrite each other.
      capture.id.hashCode & 0x7fffffff,
      l10n.notifCaptureTitle,
      _captureBody(l10n, capture, walletName),
      NotificationDetails(android: androidDetails),
      payload: capture.id,
    );
  }

  String _captureBody(
    AppLocalizations l10n,
    NotificationCapture capture,
    String? walletName,
  ) {
    final amount = capture.amount;
    final direction = capture.direction;
    if (capture.parseStatus == ParseStatus.unparsed ||
        amount == null ||
        direction == null) {
      return l10n.notifCaptureBodyUnparsed;
    }
    final amountText = formatSigned(amount,
        negative: direction == CaptureDirection.expense);
    return walletName == null
        ? l10n.notifCaptureBodyNoWallet(amountText)
        : l10n.notifCaptureBody(amountText, walletName);
  }

  void _onResponse(NotificationResponse response) {
    final actionId = response.actionId;
    final payload = response.payload;

    // Capture alert: "Thêm" action, or a plain tap on the notification body
    // (actionId is null in that case, but payload identifies the capture).
    if (payload != null &&
        (actionId == _kActionCaptureAdd || actionId == null)) {
      onOpenCapture?.call(payload);
      return;
    }
    // Capture alert "Bỏ qua": showsUserInterface is false, so Android should
    // route this to [_onResponseBackground] instead. Nothing to do here.
    if (actionId == _kActionCaptureDismiss) return;

    _navigate(_typeFromAction(actionId ?? ''));
    // Vivo OriginOS (and some other OEM skins) dismiss the notification when
    // any action button is tapped, ignoring ongoing:true. Re-post immediately.
    showPersistentNotification();
  }

  void _navigate(String? type) {
    navigatorKey.currentState?.pushNamed('/quick-add', arguments: type);
  }
}

/// Handles the "Bỏ qua" capture action when the app is backgrounded or fully
/// killed. flutter_local_notifications runs this in its own **separate
/// Flutter engine** (not a bare isolate — see the plugin's README), which on
/// Android is already plugin-registered, so `path_provider`/`sqlite3` (used
/// transitively by [AppDatabase]) work without extra setup. This opens a
/// throwaway [AppDatabase] connection (safe: the database already uses
/// `NativeDatabase.createInBackground`, so this is just another connection to
/// the same sqlite file) and writes the dismissal directly, without ever
/// bringing the app UI forward.
///
/// Because this write happens outside the live app's `AppDatabase` instance,
/// Drift's reactive `watch()` streams won't see it automatically — see the
/// `markTablesUpdated` call in `_AppLifecycleObserver.didChangeAppLifecycleState`
/// (main.dart) for the corresponding refresh-on-resume fix.
@pragma('vm:entry-point')
void _onResponseBackground(NotificationResponse response) async {
  if (response.actionId != _kActionCaptureDismiss) return;
  final captureId = response.payload;
  if (captureId == null) return;

  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  try {
    await (db.update(db.notificationCaptures)
          ..where((c) => c.id.equals(captureId)))
        .write(const NotificationCapturesCompanion(
      status: Value(CaptureStatus.dismissed),
    ));
  } finally {
    await db.close();
  }
}

String? _typeFromAction(String actionId) => switch (actionId) {
      _kActionSpending => TxTypes.spending,
      _kActionEarning => TxTypes.earning,
      _kActionTransfer => TxTypes.transfer,
      _ => null,
    };
