import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../navigation/push_notification_router.dart';

/// Background tap handler for local notifications (must be top-level).
@pragma('vm:entry-point')
void onLocalNotificationTapBackground(NotificationResponse response) {
  LocalNotificationService.handleNotificationResponse(response);
}

class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  int _counter = 0;

  static const int incomingCallNotificationId = 900001;

  static const AndroidNotificationChannel _alertsChannel =
      AndroidNotificationChannel(
    'vyooo_high_importance',
    'Vyooo Alerts',
    description: 'Realtime alerts for likes, comments, follows and more.',
    importance: Importance.max,
  );

  static const AndroidNotificationChannel _callsChannel =
      AndroidNotificationChannel(
    'vyooo_incoming_calls',
    'Incoming Calls',
    description: 'Incoming audio and video calls.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          onLocalNotificationTapBackground,
    );
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_alertsChannel);
    await androidImpl?.createNotificationChannel(_callsChannel);
    // OS permission is requested by [PushMessagingService.syncTokenForUser]
    // after sign-in so a denied pre-login prompt does not block token sync.
    _initialized = true;
  }

  static void handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload?.trim();
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      PushNotificationRouter.handleCallData(data);
    } catch (_) {}
  }

  /// Returns pending call payload when the app was cold-started from a call notification.
  Future<Map<String, dynamic>?> takeColdStartCallPayload() async {
    if (kIsWeb) return null;
    await init();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    final payload = details.notificationResponse?.payload?.trim();
    if (payload == null || payload.isEmpty) return null;
    try {
      final data = Map<String, dynamic>.from(
        jsonDecode(payload) as Map<String, dynamic>,
      );
      if ((data['type'] ?? '').toString() != 'incoming_call') return null;
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<void> show({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    await init();
    final id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 20) +
        (_counter++ % 1024);
    const android = AndroidNotificationDetails(
      'vyooo_high_importance',
      'Vyooo Alerts',
      channelDescription:
          'Realtime alerts for likes, comments, follows and more.',
      importance: Importance.max,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: android,
        iOS: ios,
      ),
    );
  }

  /// High-priority incoming call alert (full-screen on Android when permitted).
  Future<void> showIncomingCall({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    if (kIsWeb) return;
    await init();
    final payload = jsonEncode(data);
    const android = AndroidNotificationDetails(
      'vyooo_incoming_calls',
      'Incoming Calls',
      channelDescription: 'Incoming audio and video calls.',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
      categoryIdentifier: 'incoming_call',
    );
    await _plugin.show(
      id: incomingCallNotificationId,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: const NotificationDetails(
        android: android,
        iOS: ios,
      ),
    );
  }

  Future<void> dismissIncomingCall() async {
    if (kIsWeb) return;
    await init();
    await _plugin.cancel(id: incomingCallNotificationId);
  }
}
