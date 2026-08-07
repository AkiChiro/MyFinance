import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/domain.dart';

const _kActionSpending = 'add_spending';
const _kActionEarning = 'add_earning';
const _kActionTransfer = 'add_transfer';

// v2 channel: IMPORTANCE_DEFAULT (no sound) — replaces v1 (IMPORTANCE_LOW)
// which was invisible on Vivo OriginOS and other Chinese OEM skins.
const _kChannelId = 'myfinance_quick_add_v2';
const _kNotifId = 1;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  Locale _locale = const Locale('vi');

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

  void _onResponse(NotificationResponse response) {
    _navigate(_typeFromAction(response.actionId ?? ''));
    // Vivo OriginOS (and some other OEM skins) dismiss the notification when
    // any action button is tapped, ignoring ongoing:true. Re-post immediately.
    showPersistentNotification();
  }

  void _navigate(String? type) {
    navigatorKey.currentState?.pushNamed('/quick-add', arguments: type);
  }
}

@pragma('vm:entry-point')
void _onResponseBackground(NotificationResponse response) {}

String? _typeFromAction(String actionId) => switch (actionId) {
      _kActionSpending => TxTypes.spending,
      _kActionEarning => TxTypes.earning,
      _kActionTransfer => TxTypes.transfer,
      _ => null,
    };
