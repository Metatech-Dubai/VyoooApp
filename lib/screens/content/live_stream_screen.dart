import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/config/agora_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/live_chat_message_model.dart';
import '../../core/models/live_stream_model.dart';
import '../../core/services/agora_token_service.dart';
import '../../core/services/live_stream_service.dart';
import '../../core/services/viture_service.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../widgets/live_360_view.dart';
import '../../widgets/viewer_sphere_view.dart';

/// Viewer live stream screen.
/// Pass a [LiveStreamModel] to open any live stream as a viewer.
class LiveStreamScreen extends StatefulWidget {
  const LiveStreamScreen({super.key, required this.stream});

  final LiveStreamModel stream;

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  // ── Agora ─────────────────────────────────────────────────────────────────────
  late RtcEngine _engine;
  bool _engineReady = false;
  int _remoteUid = 0; // host's Agora UID — set when first remote user joins
  bool _hostVideoAvailable = false;

  // ── Firebase ──────────────────────────────────────────────────────────────────
  final _liveService = LiveStreamService();
  final _tokenService = AgoraTokenService();
  LiveStreamModel? _liveDoc;
  StreamSubscription<LiveStreamModel?>? _streamSub;
  StreamSubscription<List<LiveChatMessageModel>>? _chatSub;
  List<LiveChatMessageModel> _chatMessages = [];

  // ── VITURE XR viewer ────────────────────────────────────────────────────────────
  final _viture = VitureService();
  bool _vitureConnected = false;
  bool _xrMode = false; // user toggled into the head-tracked glasses view

  // ── UI ────────────────────────────────────────────────────────────────────────
  final _chatCtrl = TextEditingController();
  final _chatScrollCtrl = ScrollController();
  String? _toast;
  Timer? _toastTimer;
  bool _hasJoined = false;

  @override
  void initState() {
    super.initState();
    _liveDoc = widget.stream;
    _initAndJoin();
    _initViture();
  }

  Future<void> _initViture() async {
    _viture.start();
    _viture.state.addListener(_onVitureState);
    // Cheap capability probe; the actual SDK/USB connect happens when the user enters XR.
    await _viture.isSupported();
  }

  void _onVitureState() {
    if (!mounted) return;
    final connected = _viture.state.value.connected;
    if (connected != _vitureConnected) {
      setState(() {
        _vitureConnected = connected;
        // Glasses unplugged mid-session → drop out of XR so the flat view returns.
        if (!connected) _xrMode = false;
      });
    }
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _chatSub?.cancel();
    _chatCtrl.dispose();
    _chatScrollCtrl.dispose();
    _toastTimer?.cancel();
    _viture.state.removeListener(_onVitureState);
    unawaited(_viture.disconnect().catchError((_) {}));
    unawaited(_viture.dispose());
    _leaveAndDispose();
    super.dispose();
  }

  /// XR can be offered when the stream is a 360 (equirect) source and the glasses are connected.
  bool _canOfferXr(LiveStreamModel doc) =>
      ViewerSphereView.supportsNative && doc.use360Player && _vitureConnected;

  Future<void> _enterXr() async {
    // Connect the glasses on demand (USB-permission pre-flight is handled natively). If already
    // connected this is a no-op that resolves immediately.
    if (!_vitureConnected) {
      final ok = await _viture.connect();
      if (!ok && !_viture.state.value.connected) {
        _showToast(_viture.state.value.lastError ?? 'Could not connect the XR glasses');
        return;
      }
    }
    if (!mounted) return;
    setState(() => _xrMode = true);
  }

  void _exitXr() {
    if (!mounted) return;
    setState(() => _xrMode = false);
  }

  Future<void> _leaveAndDispose() async {
    if (!_engineReady) return;
    if (_hasJoined) {
      // Send leave message before leaving channel so creator sees it
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final name = user.displayName ?? user.email?.split('@').first ?? 'Viewer';
        await _liveService.sendMessage(
          streamId: widget.stream.id,
          userId: user.uid,
          username: name,
          message: '$name left the stream',
          type: ChatMessageType.system,
        ).catchError((_) {});
      }
      await _liveService.viewerLeft(widget.stream.id).catchError((_) {});
      await _engine.leaveChannel();
    }
    await _engine.release();
  }

  // ── Init ──────────────────────────────────────────────────────────────────────

  Future<void> _initAndJoin() async {
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(
      appId: AgoraConfig.appId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    _engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) async {
        _hasJoined = true;
        await _liveService.viewerJoined(widget.stream.id).catchError((_) {});
        // Send join message so the creator sees who joined
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final name = user.displayName ?? user.email?.split('@').first ?? 'Viewer';
          await _liveService.sendMessage(
            streamId: widget.stream.id,
            userId: user.uid,
            username: name,
            message: '$name joined the stream 👋',
            type: ChatMessageType.join,
          ).catchError((_) {});
        }
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        if (!mounted) return;
        setState(() {
          _remoteUid = remoteUid;
          _hostVideoAvailable = true;
        });
      },
      onUserOffline: (connection, remoteUid, reason) {
        if (!mounted) return;
        if (remoteUid == _remoteUid) {
          setState(() {
            _hostVideoAvailable = false;
            _remoteUid = 0;
          });
          _showToast('Host ended the stream');
        }
      },
      onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
        if (!mounted) return;
        final hasVideo = state == RemoteVideoState.remoteVideoStateDecoding ||
            state == RemoteVideoState.remoteVideoStateStarting;
        setState(() => _hostVideoAvailable = hasVideo);
      },
      onTokenPrivilegeWillExpire: (connection, token) async {
        try {
          final newToken = await _tokenService.renewToken(
            channelName: widget.stream.agoraChannelName,
            uid: 0,
            isHost: false,
          );
          await _engine.renewToken(newToken);
        } catch (_) {
          _showToast('Token renewal failed — stream may disconnect');
        }
      },
      onError: (err, msg) {
        if (!mounted) return;
        _showToast('Connection error');
      },
    ));

    // Ultra-low-latency audience: the default live-broadcasting audience level buffers ~1.5 s+;
    // ultra-low targets ~400 ms, cutting the viewer-side stream delay.
    await _engine.setClientRole(
      role: ClientRoleType.clientRoleAudience,
      options: const ClientRoleOptions(
        audienceLatencyLevel:
            AudienceLatencyLevelType.audienceLatencyLevelUltraLowLatency,
      ),
    );
    await _engine.enableVideo();
    await _engine.enableAudio();

    if (!mounted) return;
    setState(() => _engineReady = true);

    // Fetch signed token then join
    final token = await _tokenService.getToken(
      channelName: widget.stream.agoraChannelName,
      uid: 0,
      isHost: false,
    );

    await _engine.joinChannel(
      token: token,
      channelId: widget.stream.agoraChannelName,
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: ClientRoleType.clientRoleAudience,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );

    // Subscribe to stream metadata + chat
    _streamSub = _liveService.streamDoc(widget.stream.id).listen((doc) {
      if (!mounted) return;
      if (doc == null) return;
      setState(() => _liveDoc = doc);
      if (doc.status == LiveStreamStatus.ended) {
        _showToast('Stream has ended');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    });

    _chatSub = _liveService.chatMessages(widget.stream.id).listen((msgs) {
      if (!mounted) return;
      setState(() => _chatMessages = msgs);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chatScrollCtrl.hasClients) {
          _chatScrollCtrl.animateTo(
            _chatScrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  // ── Actions ───────────────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _chatCtrl.clear();
    try {
      await _liveService.sendMessage(
        streamId: widget.stream.id,
        userId: user.uid,
        username: user.displayName ?? user.email?.split('@').first ?? 'Viewer',
        message: text,
      );
    } catch (_) {
      _showToast('Failed to send');
    }
  }

  Future<void> _sendLike() async {
    try {
      await _liveService.addLike(widget.stream.id);
    } catch (_) {}
  }

  void _showToast(String msg) {
    setState(() => _toast = msg);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final doc = _liveDoc ?? widget.stream;
    // In XR mode the sphere is fullscreen and all chat/HUD overlays are hidden — only a minimal
    // "exit XR" control remains, so the wearer sees a clean 360 view on the glasses.
    if (_xrMode && _canOfferXr(doc)) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _buildVideoBackground(doc),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _CircleIconButton(
                    icon: Icons.fullscreen_exit_rounded,
                    onTap: _exitXr,
                  ),
                ),
              ),
            ),
            if (_toast != null) _buildToast(),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildVideoBackground(doc),
          _buildGradientOverlay(),
          // Enter-XR affordance: shown only when the glasses are connected and the stream is 360.
          if (_canOfferXr(doc))
            SafeArea(
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _CircleIconButton(
                    icon: Icons.vrpano_rounded,
                    onTap: _enterXr,
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Stack(
              children: [
                // Top bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildTopBar(doc),
                ),
                // Bottom: chat + input
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildChatList(),
                        const SizedBox(height: 8),
                        _buildInputRow(doc),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_toast != null) _buildToast(),
          // Loading state
          if (!_engineReady)
            Container(
              color: Colors.black,
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoBackground(LiveStreamModel doc) {
    // XR mode: VITURE glasses connected + a 360 (equirect) stream → render the live Agora ERP frames
    // on a native head-tracked sphere, fullscreen. This consumes the Agora remote video directly
    // (via a video-frame observer inside ViewerSphereView), so it does NOT need the Media Push URL.
    if (_xrMode && _canOfferXr(doc) && _engineReady) {
      return ViewerSphereView(
        engine: _engine,
        remoteUid: _remoteUid, // 0 = any remote until the host's uid is known
      );
    }
    // Interactive 360: when the stream is tagged 360 AND exposes a playable URL
    // (via Media Push), render it on the sphere with gyro/touch. The URL is an
    // independent source, so this doesn't wait on the Agora remote video. Any 360
    // stream without a URL falls through to the flat Agora path below.
    if (doc.canRenderInteractive360) {
      return Live360View(streamUrl: doc.hlsUrl!);
    }
    if (!_engineReady || !_hostVideoAvailable || _remoteUid == 0) {
      // No video yet — show host avatar placeholder
      return Container(
        color: const Color(0xFF0A000F),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                backgroundImage: doc.hostProfileImage?.isNotEmpty == true
                    ? NetworkImage(doc.hostProfileImage!)
                    : null,
                child: doc.hostProfileImage?.isNotEmpty != true
                    ? Text(
                        doc.hostUsername.isNotEmpty ? doc.hostUsername[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w600),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                doc.hostUsername,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Connecting to stream...',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _engine,
        canvas: VideoCanvas(uid: _remoteUid),
        connection: RtcConnection(channelId: widget.stream.agoraChannelName),
      ),
    );
  }

  Widget _buildToast() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(_toast!, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.55),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.88),
          ],
          stops: const [0.0, 0.15, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildTopBar(LiveStreamModel doc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Back
          _CircleIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 10),
          // Host avatar + name
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            backgroundImage: doc.hostProfileImage?.isNotEmpty == true ? NetworkImage(doc.hostProfileImage!) : null,
            child: doc.hostProfileImage?.isNotEmpty != true
                ? Text(doc.hostUsername[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 13))
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  doc.hostUsername,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  doc.title,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // LIVE badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.deleteRed,
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          // Viewer count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.remove_red_eye_outlined, color: Colors.white.withValues(alpha: 0.85), size: 14),
                const SizedBox(width: 4),
                Text(
                  _formatCount(doc.viewerCount),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    if (_chatMessages.isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 150),
      child: ListView.builder(
        controller: _chatScrollCtrl,
        shrinkWrap: true,
        itemCount: _chatMessages.length,
        itemBuilder: (context, i) {
          final m = _chatMessages[i];
          if (m.type == ChatMessageType.system) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Center(
                child: Text(
                  m.message,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  backgroundImage: m.profileImage?.isNotEmpty == true ? NetworkImage(m.profileImage!) : null,
                  child: m.profileImage?.isNotEmpty != true
                      ? Text(m.username[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10))
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, height: 1.3),
                      children: [
                        TextSpan(
                          text: '${m.username} ',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: m.message,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputRow(LiveStreamModel doc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Comment...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendLike,
            child: Row(
              children: [
                Icon(Icons.favorite_rounded, color: Colors.white.withValues(alpha: 0.9), size: 20),
                const SizedBox(width: 4),
                Text(_formatCount(doc.likeCount), style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.reply_rounded, color: Colors.white.withValues(alpha: 0.9), size: 21),
        ],
      ),
    );
  }
}

// ── Shared widget ──────────────────────────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.42),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
