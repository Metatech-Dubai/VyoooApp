import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/chat/models/call_session_model.dart';
import '../../features/chat/services/call_signaling_service.dart';
import '../../features/chat/utils/chat_helpers.dart';
import 'incoming_call_kit_service.dart';

class GlobalIncomingCallService {
  GlobalIncomingCallService._();
  static final GlobalIncomingCallService instance =
      GlobalIncomingCallService._();

  final CallSignalingService _signaling = CallSignalingService();
  StreamSubscription<List<CallSessionModel>>? _sub;
  String? _uid;
  final Set<String> _shownCallIds = {};
  bool _showing = false;

  void startForUser(String uid) {
    if (uid.isEmpty) return;
    if (_uid == uid && _sub != null) return;
    stop();
    _uid = uid;
    _sub = _signaling.watchIncomingCalls(uid).listen(_onIncomingCalls);
    unawaited(checkPendingCallsOnResume());
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _uid = null;
    _shownCallIds.clear();
    _showing = false;
  }

  /// Catches ringing calls missed while the app was backgrounded.
  Future<void> checkPendingCallsOnResume() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty || _showing) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('callSessions')
          .where('participantIds', arrayContains: uid)
          .where('status', isEqualTo: CallStatus.ringing)
          .limit(5)
          .get();
      final calls = snap.docs
          .map(CallSessionModel.fromFirestore)
          .where((c) => c.calleeIds.contains(uid))
          .toList();
      if (calls.isNotEmpty) {
        _onIncomingCalls(calls);
      }
    } catch (_) {}
  }

  void _onIncomingCalls(List<CallSessionModel> calls) {
    if (_showing) return;
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    if (calls.isEmpty) return;

    final call = calls.first;
    if (_shownCallIds.contains(call.id)) return;

    _shownCallIds.add(call.id);
    _showing = true;

    _resolveCallerInfo(call).then((info) async {
      await IncomingCallKitService.instance.presentFromCallSession(
        call,
        callerName: info.$1,
        callerAvatar: info.$2,
      );
      _showing = false;
    });
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
      final dn = callerInfo['displayName'] as String?;
      final un = callerInfo['username'] as String?;
      final avatar = ChatHelpers.participantAvatarFromMap(callerInfo);
      return (dn ?? un, avatar);
    } catch (_) {
      return (null, null);
    }
  }
}
