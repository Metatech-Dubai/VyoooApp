import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/app_network_avatar.dart';
import '../models/call_session_model.dart';
import '../services/call_signaling_service.dart';
import '../services/chat_call_service.dart';
import '../utils/chat_helpers.dart';

class ChatCallScreen extends StatefulWidget {
  const ChatCallScreen({
    super.key,
    required this.callSession,
    required this.currentUid,
    this.callerName,
    this.remoteAvatarUrl,
    this.remoteUserId,
  });

  final CallSessionModel callSession;
  final String currentUid;
  final String? callerName;
  final String? remoteAvatarUrl;
  final String? remoteUserId;

  @override
  State<ChatCallScreen> createState() => _ChatCallScreenState();
}

class _ChatCallScreenState extends State<ChatCallScreen> {
  final ChatCallService _callService = ChatCallService.instance;
  final CallSignalingService _signaling = CallSignalingService();
  StreamSubscription<CallSessionModel?>? _callSub;
  CallSessionModel? _liveSession;
  bool _ended = false;
  Timer? _durationTimer;
  int _durationSeconds = 0;
  bool _initializing = true;
  String? _error;
  String? _resolvedAvatarUrl;
  String? _resolvedDisplayName;

  bool get _isVideo => widget.callSession.type == CallType.video;

  String get _remoteUid {
    final explicit = widget.remoteUserId?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final session = widget.callSession;
    if (session.callerId == widget.currentUid) {
      for (final id in session.participantIds) {
        if (id != widget.currentUid) return id;
      }
      for (final id in session.calleeIds) {
        if (id != widget.currentUid) return id;
      }
    }
    return session.callerId;
  }

  String? get _avatarUrl {
    final direct = widget.remoteAvatarUrl?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final resolved = _resolvedAvatarUrl?.trim();
    if (resolved != null && resolved.isNotEmpty) return resolved;
    return null;
  }

  String get _displayName {
    final direct = widget.callerName?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final resolved = _resolvedDisplayName?.trim();
    if (resolved != null && resolved.isNotEmpty) return resolved;
    return 'Call';
  }

  @override
  void initState() {
    super.initState();
    _liveSession = widget.callSession;
    unawaited(_resolveRemoteProfile());
    _initCall();
    _callSub = _signaling.watchCall(widget.callSession.id).listen((session) {
      if (!mounted) return;
      if (session == null ||
          session.status == CallStatus.ended ||
          session.status == CallStatus.missed ||
          session.status == CallStatus.declined ||
          session.status == CallStatus.failed) {
        _handleRemoteEnd();
        return;
      }
      setState(() => _liveSession = session);
      if (session.status == CallStatus.active && _durationTimer == null) {
        _startDurationTimer();
      }
    });
  }

  Future<void> _resolveRemoteProfile() async {
    final hasAvatar = widget.remoteAvatarUrl?.trim().isNotEmpty == true;
    final hasName = widget.callerName?.trim().isNotEmpty == true;
    if (hasAvatar && hasName) return;

    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.callSession.chatId)
          .get();
      if (!chatDoc.exists) return;
      final data = chatDoc.data();
      if (data == null) return;

      final remoteUid = _remoteUid;
      if (remoteUid.isEmpty) return;

      final pMap = data['participantMap'] as Map<String, dynamic>?;
      final participant = pMap?[remoteUid] as Map<String, dynamic>?;
      if (participant == null) return;

      final avatar = ChatHelpers.participantAvatarFromMap(participant);
      final name = ChatHelpers.participantDisplayNameFromMap(participant);
      if (!mounted) return;
      setState(() {
        if (!hasAvatar && avatar != null) _resolvedAvatarUrl = avatar;
        if (!hasName && name != null) _resolvedDisplayName = name;
      });
    } catch (e) {
      debugPrint('[ChatCallScreen] resolveRemoteProfile failed: $e');
    }
  }

  Future<void> _initCall() async {
    try {
      final isCaller = widget.callSession.callerId == widget.currentUid;
      debugPrint(
        '[ChatCallScreen] _initCall: session=${widget.callSession.id} channel=${widget.callSession.agoraChannelName} isVideo=$_isVideo status=${widget.callSession.status} role=${isCaller ? "caller" : "recipient"}',
      );
      final hasPerms = await _callService.requestPermissions(isVideo: _isVideo);
      if (!hasPerms) {
        debugPrint('[ChatCallScreen] _initCall: permissions denied');
        setState(() {
          _error = 'Permissions denied';
          _initializing = false;
        });
        return;
      }
      await _callService.initEngine();
      _callService.addListener(_onCallStateChanged);
      await _callService.joinChannel(
        channelName: widget.callSession.agoraChannelName,
        isVideo: _isVideo,
      );
      debugPrint(
        '[ChatCallScreen] _initCall: joinChannel returned, localUid=${_callService.localUid}',
      );
      try {
        await _signaling.updateAgoraUid(
          callId: widget.callSession.id,
          uid: widget.currentUid,
          agoraUid: _callService.localUid,
        );
        debugPrint('[ChatCallScreen] _initCall: updateAgoraUid OK');
      } catch (e) {
        debugPrint(
          '[ChatCallScreen] _initCall: updateAgoraUid failed (non-fatal): $e',
        );
      }
      if (mounted) setState(() => _initializing = false);
    } catch (e) {
      debugPrint('[ChatCallScreen] _initCall failed: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to join call: $e';
          _initializing = false;
        });
      }
    }
  }

  void _onCallStateChanged() {
    if (mounted) setState(() {});
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _durationSeconds++);
    });
  }

  void _handleRemoteEnd() {
    if (_ended) return;
    _ended = true;
    _cleanup();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _endCall() async {
    if (_ended) return;
    _ended = true;
    try {
      await _signaling.endCall(
        callId: widget.callSession.id,
        uid: widget.currentUid,
      );
    } catch (_) {}
    _cleanup();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _cleanup() async {
    _durationTimer?.cancel();
    _callService.removeListener(_onCallStateChanged);
    await _callService.leaveChannel();
    await _callService.dispose_();
  }

  @override
  void dispose() {
    _callSub?.cancel();
    _durationTimer?.cancel();
    _callService.removeListener(_onCallStateChanged);
    if (!_ended) {
      _signaling
          .endCall(callId: widget.callSession.id, uid: widget.currentUid)
          .catchError((_) {});
      _callService.leaveChannel().catchError((_) {});
      _callService.dispose_().catchError((_) {});
    }
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF07010F),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    }

    if (_initializing) {
      return const Scaffold(
        backgroundColor: Color(0xFF07010F),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFDE106B)),
              SizedBox(height: 16),
              Text('Connecting...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF07010F),
      body: SafeArea(child: _isVideo ? _buildVideoUI() : _buildAudioUI()),
    );
  }

  Widget _buildAudioUI() {
    final status = _liveSession?.status ?? '';
    final statusText = status == CallStatus.active
        ? _formatDuration(_durationSeconds)
        : status == CallStatus.ringing
        ? 'Ringing...'
        : 'Connecting...';
    final avatarUrl = _avatarUrl ?? '';
    final remoteUid = _remoteUid;

    return Column(
      children: [
        const Spacer(flex: 2),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFFDE106B), Color(0xFF6B21A8)],
            ),
          ),
          child: CircleAvatar(
            radius: 56,
            backgroundColor: const Color(0xFF1A0A2E),
            child: ClipOval(
              child: AppNetworkAvatar(
                imageUrl: avatarUrl,
                userId: remoteUid.isEmpty ? null : remoteUid,
                size: 112,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          statusText,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 16,
          ),
        ),
        const Spacer(flex: 3),
        _buildControls(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildVideoUI() {
    final remoteUids = _callService.remoteUids.toList();

    return Stack(
      children: [
        if (remoteUids.isEmpty)
          const Center(
            child: Text(
              'Waiting for other participant...',
              style: TextStyle(color: Colors.white54),
            ),
          )
        else if (remoteUids.length == 1)
          Positioned.fill(
            child: AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _callService.engine!,
                canvas: VideoCanvas(uid: remoteUids.first),
                connection: RtcConnection(
                  channelId: widget.callSession.agoraChannelName,
                ),
              ),
            ),
          )
        else
          _buildGroupVideoGrid(remoteUids),

        if (!_callService.cameraMuted)
          Positioned(
            top: 16,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 120,
                height: 160,
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _callService.engine!,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              ),
            ),
          ),

        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _liveSession?.status == CallStatus.active
                  ? _formatDuration(_durationSeconds)
                  : 'Connecting...',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),

        Positioned(bottom: 40, left: 0, right: 0, child: _buildControls()),
      ],
    );
  }

  Widget _buildGroupVideoGrid(List<int> remoteUids) {
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: remoteUids.length <= 4 ? 2 : 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: remoteUids.length,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _callService.engine!,
              canvas: VideoCanvas(uid: remoteUids[index]),
              connection: RtcConnection(
                channelId: widget.callSession.agoraChannelName,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _controlButton(
          icon: _callService.micMuted ? Icons.mic_off : Icons.mic,
          label: _callService.micMuted ? 'Unmute' : 'Mute',
          active: _callService.micMuted,
          onTap: () => _callService.toggleMic(),
        ),
        if (_isVideo)
          _controlButton(
            icon: _callService.cameraMuted
                ? Icons.videocam_off
                : Icons.videocam,
            label: 'Camera',
            active: _callService.cameraMuted,
            onTap: () => _callService.toggleCamera(),
          ),
        if (_isVideo)
          _controlButton(
            icon: Icons.cameraswitch,
            label: 'Flip',
            active: false,
            onTap: () => _callService.switchCamera(),
          ),
        _controlButton(
          icon: _callService.speakerOn ? Icons.volume_up : Icons.hearing,
          label: _callService.speakerOn ? 'Speaker' : 'Earpiece',
          active: _callService.speakerOn,
          onTap: () => _callService.toggleSpeaker(),
        ),
        _controlButton(
          icon: Icons.call_end,
          label: 'End',
          active: false,
          isEnd: true,
          onTap: _endCall,
        ),
      ],
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    bool isEnd = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isEnd
                  ? Colors.red
                  : active
                  ? Colors.white24
                  : Colors.white12,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
