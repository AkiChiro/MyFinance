import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/domain.dart';

// ---------------------------------------------------------------------------
// Notification action IDs — matched in the response callback.
// ---------------------------------------------------------------------------
const _kActionSpending = 'add_spending';
const _kActionEarning = 'add_earning';
const _kActionTransfer = 'add_transfer';

const _kChannelId = 'myfinance_quick_add';
const _kNotifId = 1;

// Global navigator key so the notification callback can push a route even
// when the app is in the background (but still alive).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('ic_notif');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: _onResponseBackground,
    );

    // Request POST_NOTIFICATIONS permission (Android 13+).
    // Wrapped individually — failure here must not block the persistent
    // notification on older Android versions.
    try {
      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    } catch (_) {}

    try {
      await showPersistentNotification();
    } catch (_) {}
  }

  Future<void> showPersistentNotification() async {
    const androidDetails = AndroidNotificationDetails(
      _kChannelId,
      'Thêm nhanh',
      channelDescription: 'Nút thêm giao dịch nhanh từ thanh thông báo',
      importance: Importance.low,
      priority: Priority.low,
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
    final type = _typeFromAction(response.actionId ?? '');
    _navigate(type);
  }

  void _navigate(String? type) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    // Import lazily to avoid circular dependency.
    // ignore: avoid_dynamic_calls
    nav.pushNamed('/quick-add', arguments: type);
  }
}

// Top-level (isolate-safe) background callback.
@pragma('vm:entry-point')
void _onResponseBackground(NotificationResponse response) {
  // When the app is fully terminated, the tap will cold-start it via
  // MainActivity's intent — nothing to do here.
}

String? _typeFromAction(String actionId) {
  return switch (actionId) {
    _kActionSpending => TxTypes.spending,
    _kActionEarning => TxTypes.earning,
    _kActionTransfer => TxTypes.transfer,
    _ => null,
  };
}
