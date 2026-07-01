import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

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

  /// Initialise the plugin and, if [enabled] is true, request POST_NOTIFICATIONS
  /// permission (Android 13+) before showing the persistent notification.
  Future<void> init({bool enabled = true}) async {
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

  Future<void> showPersistentNotification() async {
    const androidDetails = AndroidNotificationDetails(
      _kChannelId,
      'Thêm nhanh',
      channelDescription: 'Nút thêm giao dịch nhanh từ thanh thông báo',
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
        AndroidNotificationAction(_kActionSpending, 'Chi tiêu',
            showsUserInterface: true),
        AndroidNotificationAction(_kActionEarning, 'Thu nhập',
            showsUserInterface: true),
        AndroidNotificationAction(_kActionTransfer, 'Chuyển khoản',
            showsUserInterface: true),
      ],
    );

    await _plugin.show(
      _kNotifId,
      'MyFinance',
      'Nhấn để ghi giao dịch nhanh',
      const NotificationDetails(android: androidDetails),
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
