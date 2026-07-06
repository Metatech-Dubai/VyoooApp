import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../screens/notifications/notification_screen.dart';
import '../navigation/app_keys.dart';
import '../services/incoming_call_kit_service.dart';

class PushNotificationRouter {
  PushNotificationRouter._();

  static void handleMessage(RemoteMessage message) {
    handleCallData(message.data);
  }

  static void handleCallData(Map<String, dynamic> data) {
    if (data.isEmpty) return;

    final type = (data['type'] ?? '').toString().trim().toLowerCase();

    if (type == 'incoming_call') {
      unawaited(
        IncomingCallKitService.instance.presentIncomingCall(
          data: data,
        ),
      );
      return;
    }

    if (type == 'chat_message') {
      return;
    }

    final nav = appNavigatorKey.currentState;
    if (nav == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (appNavigatorKey.currentState == null) return;
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => const NotificationScreen(),
        ),
      );
    });
  }
}
