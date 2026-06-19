import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming_maintained/entities/entities.dart';
import 'package:flutter_callkit_incoming_maintained/flutter_callkit_incoming_maintained.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../features/chat/models/call_session_model.dart';
import '../../features/chat/screens/chat_call_screen.dart';
import '../../features/chat/services/call_signaling_service.dart';
import '../../features/chat/utils/chat_helpers.dart';
import '../../firebase_options.dart';
import '../navigation/app_keys.dart';
import '../utils/call_kit_id.dart';

/// Background CallKit events (accept/decline while app is terminated).
@pragma('vm:entry-point')
Future<void> incomingCallKitBackgroundHandler(CallEvent event) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await IncomingCallKitService.instance.handleBackgroundEvent(event);
}

/// Native incoming-call UI (CallKit on iOS, full-screen Telecom UI on Android).
class IncomingCallKitService {
  IncomingCallKitService._();
  static final IncomingCallKitService instance = IncomingCallKitService._();

  final CallSignalingService _signaling = CallSignalingService();
  final Set<String> _presentedCallIds = <String>{};
  final Map<String, String> _callKitIdToFirestoreId = <String, String>{};
  StreamSubscription<CallEvent?>? _eventSub;
  bool _configured = false;
  bool _handlingAction = false;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get _isApple =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> configure() async {
    if (kIsWeb || _configured) return;
    _configured = true;

    if (_isAndroid) {
      await FlutterCallkitIncoming.onBackgroundMessage(
        incomingCallKitBackgroundHandler,
      );
      await FlutterCallkitIncoming.requestFullIntentPermission();
      final canFullScreen = await FlutterCallkitIncoming.canUseFullScreenIntent();
      if (kDebugMode) {
        debugPrint('CallKit Android fullScreenIntent allowed: $canFullScreen');
      }
    }

    _eventSub = FlutterCallkitIncoming.onEvent.listen(_onCallKitEvent);
    unawaited(syncVoipTokenWithRetry());
    unawaited(checkAcceptedCallOnResume());
  }

  /// VoIP token can arrive a few seconds after PushKit registers.
  Future<void> syncVoipTokenWithRetry({int attempts = 8}) async {
    for (var i = 0; i < attempts; i++) {
      if (i > 0) {
        await Future<void>.delayed(Duration(seconds: 1 + i));
      }
      await syncVoipTokenForCurrentUser();
      if (!_isApple || kIsWeb) return;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) return;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('push_tokens')
            .doc('voip')
            .get();
        if (doc.exists && (doc.data()?['token'] as String?)?.isNotEmpty == true) {
          return;
        }
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await _eventSub?.cancel();
    _eventSub = null;
    _configured = false;
  }

  /// Persist iOS VoIP token for server-side VoIP pushes (wakes app when killed).
  Future<void> syncVoipTokenForCurrentUser() async {
    if (!_isApple || kIsWeb) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    final token = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
    if (token == null || token.trim().isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('push_tokens')
          .doc('voip')
          .set({
        'token': token.trim(),
        'platform': 'ios',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (kDebugMode) debugPrint('VoIP token saved for $uid');
    } catch (e) {
      if (kDebugMode) debugPrint('VoIP token persist failed: $e');
    }
  }

  Future<void> clearVoipTokenForSignOut(String uid) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('push_tokens')
          .doc('voip')
          .delete();
    } catch (_) {}
  }

  Future<void> presentIncomingCall({
    required Map<String, dynamic> data,
    String? callerName,
    String? callerAvatar,
  }) async {
    if (kIsWeb) return;

    final callId = (data['callId'] ?? '').toString().trim();
    if (callId.isEmpty) return;
    if (_presentedCallIds.contains(callId)) return;
    _presentedCallIds.add(callId);

    final callType = (data['callType'] ?? 'audio').toString().trim().toLowerCase();
    final isVideo = callType == 'video';
    final resolvedName = callerName?.trim().isNotEmpty == true
        ? callerName!.trim()
        : (data['nameCaller'] ?? '').toString().trim();
    final name = resolvedName.isNotEmpty ? resolvedName : 'Vyooo';
    final avatar = callerAvatar?.trim();

    final extra = Map<String, dynamic>.from(data);
    extra['type'] = 'incoming_call';
    extra['callId'] = callId;

    final nativeCallId = _isApple ? callKitUuidFor(callId) : callId;
    if (_isApple) {
      _callKitIdToFirestoreId[nativeCallId] = callId;
    }

    if (_isAndroid) {
      // Pre-request so accept → ongoing-call FGS can use microphone type when eligible.
      unawaited(Permission.microphone.request());
      if (isVideo) {
        unawaited(Permission.camera.request());
      }
    }

    final params = CallKitParams(
      id: nativeCallId,
      nameCaller: name,
      appName: 'Vyooo',
      avatar: avatar?.isNotEmpty == true ? avatar : null,
      handle: isVideo ? 'Video call' : 'Audio call',
      type: isVideo ? 1 : 0,
      duration: 45000,
      extra: extra,
      missedCallNotification: const NotificationParams(
        showNotification: true,
        subtitle: 'Missed call',
        isShowCallback: false,
      ),
      callingNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: true,
        subtitle: 'On a call',
        callbackText: 'Hang up',
      ),
      android: const AndroidParams(
        // Custom notification + fullScreenIntent; accept-crash fixes are in the
        // vendored plugin (channel creation + ongoing notification).
        isCustomNotification: true,
        isShowLogo: false,
        isFullScreen: true,
        isShowFullLockedScreen: true,
        isImportant: true,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0D0015',
        actionColor: '#4CAF50',
        textColor: '#ffffff',
        textAccept: 'Accept',
        textDecline: 'Decline',
        incomingCallNotificationChannelName: 'Vyooo Incoming Calls',
        missedCallNotificationChannelName: 'Vyooo Missed Calls',
      ),
      ios: IOSParams(
        handleType: 'generic',
        supportsVideo: isVideo,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        supportsDTMF: false,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  Future<void> presentFromCallSession(
    CallSessionModel call, {
    String? callerName,
    String? callerAvatar,
  }) async {
    await presentIncomingCall(
      data: {
        'type': 'incoming_call',
        'callId': call.id,
        'chatId': call.chatId,
        'callerId': call.callerId,
        'callType': call.type,
        'agoraChannelName': call.agoraChannelName,
      },
      callerName: callerName,
      callerAvatar: callerAvatar,
    );
  }

  Future<void> dismissCall(String callId) async {
    if (callId.isEmpty) return;
    _presentedCallIds.remove(callId);
    final nativeId = _isApple ? callKitUuidFor(callId) : callId;
    _callKitIdToFirestoreId.remove(nativeId);
    try {
      await FlutterCallkitIncoming.endCall(nativeId);
    } catch (_) {}
  }

  /// When user accepted from CallKit while app was backgrounded/killed.
  Future<void> checkAcceptedCallOnResume() async {
    if (kIsWeb) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty || _handlingAction) return;

    try {
      final active = await FlutterCallkitIncoming.activeCalls();
      for (final call in active) {
        if (!call.isAccepted) continue;
        final nativeId = call.id.trim();
        if (nativeId.isEmpty) continue;
        final firestoreCallId = await _firestoreCallIdFromNativeId(nativeId);
        await _handleAccept(firestoreCallId, fromResume: true);
        return;
      }
    } catch (_) {}
  }

  Future<void> handleBackgroundEvent(CallEvent event) async {
    await _dispatchEvent(event);
  }

  Future<void> _onCallKitEvent(CallEvent? event) async {
    if (event == null) return;
    await _dispatchEvent(event);
  }

  Future<void> _dispatchEvent(CallEvent event) async {
    switch (event) {
      case CallEventActionDidUpdateDevicePushTokenVoip():
        await syncVoipTokenForCurrentUser();
      case CallEventActionCallAccept(:final id):
        await _handleAccept(await _firestoreCallIdFromNativeId(id));
      case CallEventActionCallDecline(:final id):
        await _handleDecline(await _firestoreCallIdFromNativeId(id));
      case CallEventActionCallEnded(:final id):
        _presentedCallIds.remove(await _firestoreCallIdFromNativeId(id));
      case CallEventActionCallTimeout(:final id):
        await _handleTimeout(await _firestoreCallIdFromNativeId(id));
      default:
        break;
    }
  }

  Future<void> _handleAccept(String callId, {bool fromResume = false}) async {
    if (callId.isEmpty || _handlingAction) return;
    _handlingAction = true;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) return;

      final doc = await FirebaseFirestore.instance
          .collection('callSessions')
          .doc(callId)
          .get();
      if (!doc.exists) {
        await dismissCall(callId);
        return;
      }

      final session = CallSessionModel.fromFirestore(doc);
      if (!session.calleeIds.contains(uid)) return;

      if (session.status == CallStatus.ringing) {
        await _signaling.acceptCall(callId: callId, uid: uid);
      } else if (session.status != CallStatus.active) {
        await dismissCall(callId);
        return;
      }

      await FlutterCallkitIncoming.setCallConnected(
        _isApple ? callKitUuidFor(callId) : callId,
      );

      final callerInfo = await _resolveCallerInfo(session);
      final activeSession = session.status == CallStatus.active
          ? session
          : session.copyWith(status: CallStatus.active);

      if (!fromResume) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }

      final nav = appNavigatorKey.currentState;
      if (nav == null) return;

      final remoteUid = session.callerId == uid
          ? session.participantIds.firstWhere(
              (id) => id != uid,
              orElse: () => session.calleeIds.firstWhere(
                (id) => id != uid,
                orElse: () => '',
              ),
            )
          : session.callerId;

      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => ChatCallScreen(
            callSession: activeSession,
            currentUid: uid,
            callerName: callerInfo.$1,
            remoteAvatarUrl: callerInfo.$2,
            remoteUserId: remoteUid.isEmpty ? null : remoteUid,
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('CallKit accept failed: $e');
      await dismissCall(callId);
    } finally {
      _handlingAction = false;
    }
  }

  Future<void> _handleDecline(String callId) async {
    if (callId.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      await _signaling.declineCall(callId: callId, uid: uid);
    } catch (_) {}
    await dismissCall(callId);
  }

  Future<void> _handleTimeout(String callId) async {
    _presentedCallIds.remove(callId);
    await dismissCall(callId);
  }

  Future<String> _firestoreCallIdFromNativeId(String nativeId) async {
    final cached = _callKitIdToFirestoreId[nativeId];
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final active = await FlutterCallkitIncoming.activeCalls();
      for (final call in active) {
        if (call.id != nativeId) continue;
        final fromExtra = (call.extra?['callId'] ?? '').toString().trim();
        if (fromExtra.isNotEmpty) return fromExtra;
      }
    } catch (_) {}

    return nativeId;
  }

  Future<(String?, String?)> _resolveCallerInfo(CallSessionModel call) async {
    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(call.chatId)
          .get();
      if (!chatDoc.exists) return (null, null);
      final data = chatDoc.data();
      if (data == null) return (null, null);
      final pMap = data['participantMap'] as Map<String, dynamic>?;
      if (pMap == null) return (null, null);
      final callerInfo = pMap[call.callerId] as Map<String, dynamic>?;
      if (callerInfo == null) return (null, null);
      return (
        ChatHelpers.participantDisplayNameFromMap(callerInfo),
        ChatHelpers.participantAvatarFromMap(callerInfo),
      );
    } catch (_) {
      return (null, null);
    }
  }
}
