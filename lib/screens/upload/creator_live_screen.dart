import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vyooo/core/widgets/app_gradient_background.dart';

import '../../core/config/agora_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/live_chat_message_model.dart';
import '../../core/models/live_stream_model.dart';
import '../../core/models/video_360_metadata.dart';
import '../../core/services/agora_token_service.dart';
import '../../core/services/insta360_live_service.dart';
import '../../core/services/live_stream_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/story/story_upload_screen.dart';
import '../../widgets/insta360_preview_view.dart';
import 'upload_screen.dart';
import 'widgets/upload_create_bottom_bar.dart';

// ── State enum ─────────────────────────────────────────────────────────────────

enum _LiveState { initializing, permissionDenied, offline, countdown, live }

/// Active broadcast camera source. `phone` = Agora's built-in camera (default);
/// `insta360` = the Insta360 360° camera pushed in as an Agora external video source.
enum _CameraSource { phone, insta360 }

// ── Screen ─────────────────────────────────────────────────────────────────────

/// Creator live streaming screen.
/// Handles camera preview → countdown → live broadcast with Agora + Firebase.
class CreatorLiveScreen extends StatefulWidget {
  const CreatorLiveScreen({super.key});

  @override
  State<CreatorLiveScreen> createState() => _CreatorLiveScreenState();
}

class _CreatorLiveScreenState extends State<CreatorLiveScreen> {
  // ── Agora ────────────────────────────────────────────────────────────────────
  late RtcEngine _engine;
  bool _engineReady = false;
  int _localUid = 0;
  int _engineVersion =
      0; // incremented on each init — forces AgoraVideoView to rebuild

  // ── State ─────────────────────────────────────────────────────────────────────
  _LiveState _liveState = _LiveState.initializing;
  int _countdown = 3;
  Timer? _countdownTimer;
  Timer? _heartbeatTimer;

  // ── Controls ──────────────────────────────────────────────────────────────────
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isCommentsOff = false;
  bool _isFrontCamera = true;

  // ── Camera source (phone ↔ Insta360 360°) ─────────────────────────────────────
  final Insta360LiveService _insta = Insta360LiveService();
  _CameraSource _cameraSource = _CameraSource.phone;
  bool _insta360Supported = false;
  bool _insta360Switching = false;
  bool _instaWasConnected = false;
  bool _maskEnabled = true;
  StreamSubscription<Insta360Frame>? _instaFrameSub;
  Timer? _instaConnectTimer;

  // Interactive 360 view orientation (degrees), driven by host drag on the preview.
  double _viewYaw = 0;
  double _viewPitch = 0;
  static const double _kDragDegPerPx = 0.2;

  // Horizontal jog slider (spring-return): displacement from centre rotates yaw continuously in
  // sub-degree steps; release recentres the thumb and the view holds its angle.
  double _jogYaw = 0.0;
  bool _jogActive = false;
  Timer? _jogTimer;
  // Constant rotation rate while the slider is held off-centre — the slider sets DIRECTION only,
  // not speed, so it stays slow regardless of how far it's pushed. ~1°/sec at a 40ms tick.
  static const double _kJogStepDeg = 0.04;

  // ── Toast ─────────────────────────────────────────────────────────────────────
  String? _toast;
  Timer? _toastTimer;

  // ── Firebase ──────────────────────────────────────────────────────────────────
  final _liveService = LiveStreamService();
  final _tokenService = AgoraTokenService();
  final _userService = UserService();
  String? _streamId;
  LiveStreamModel? _streamDoc;
  StreamSubscription<LiveStreamModel?>? _streamSub;
  StreamSubscription<List<LiveChatMessageModel>>? _chatSub;
  List<LiveChatMessageModel> _chatMessages = [];

  // ── Settings ──────────────────────────────────────────────────────────────────
  String _streamTitle = '';
  String _streamDescription = '';
  String _streamCategory = '';
  List<String> _streamTags = [];
  int _streamPrice = 0;

  // ── Chat input ─────────────────────────────────────────────────────────────────
  final _chatCtrl = TextEditingController();
  final _chatScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _init();
    // Probe Insta360 capability + watch for mid-stream camera drop (fallback to phone).
    _insta.start();
    _insta.state.addListener(_onInstaState);
    _insta.isSupported().then((ok) {
      if (mounted) setState(() => _insta360Supported = ok);
    });
  }

  /// Reflect Insta360 status changes in the UI and handle a real mid-session disconnect.
  /// Only falls back on a genuine connected→disconnected transition (never during the initial
  /// OPENING window, which would abort a connection that is still in progress).
  void _onInstaState() {
    final connected = _insta.state.value.connected;
    if (connected) _instaConnectTimer?.cancel();
    final droppedMidSession = _cameraSource == _CameraSource.insta360 &&
        _instaWasConnected &&
        !connected &&
        !_insta360Switching;
    _instaWasConnected = connected;
    if (mounted) setState(() {}); // gate the preview / refresh status chip
    if (droppedMidSession) {
      _showToast('360 camera disconnected — switched to phone');
      _disableInsta360();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _heartbeatTimer?.cancel();
    _toastTimer?.cancel();
    _streamSub?.cancel();
    _chatSub?.cancel();
    _chatCtrl.dispose();
    _chatScrollCtrl.dispose();
    _instaConnectTimer?.cancel();
    _jogTimer?.cancel();
    _instaFrameSub?.cancel();
    _insta.state.removeListener(_onInstaState);
    if (_cameraSource == _CameraSource.insta360) {
      _insta.setFrameStreaming(false).catchError((_) {});
      _insta.disconnect().catchError((_) {});
    }
    _insta.dispose();
    _disposeEngine();
    super.dispose();
  }

  Future<void> _disposeEngine() async {
    // Auto-end stream if host closes the screen without pressing End Stream
    if (_streamId != null && _liveState == _LiveState.live) {
      await _liveService.endStream(_streamId!).catchError((_) {});
    }
    if (_engineReady) {
      await _engine.stopPreview();
      await _engine.leaveChannel();
      await _engine.release();
    }
  }

  // ── Init ──────────────────────────────────────────────────────────────────────

  Future<void> _init() async {
    final granted = await _requestPermissions();
    if (!mounted) return;
    if (!granted) {
      setState(() => _liveState = _LiveState.permissionDenied);
      return;
    }
    await _initAgora();
  }

  Future<bool> _requestPermissions() async {
    final statuses = await [Permission.camera, Permission.microphone].request();
    return statuses[Permission.camera]!.isGranted &&
        statuses[Permission.microphone]!.isGranted;
  }

  Future<void> _initAgora() async {
    _engine = createAgoraRtcEngine();
    await _engine.initialize(
      RtcEngineContext(
        appId: AgoraConfig.appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          if (!mounted) return;
          setState(() => _localUid = connection.localUid ?? 0);
          if (_streamId != null) {
            _liveService.updateHostAgoraUid(_streamId!, _localUid);
          }
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          if (_streamId == null) return;
          _liveService
              .sendMessage(
                streamId: _streamId!,
                userId: 'system',
                username: 'system',
                message: 'Someone joined the stream 👋',
                type: ChatMessageType.join,
              )
              .catchError((_) {});
        },
        onUserOffline: (connection, remoteUid, reason) {
          if (_streamId == null) return;
          _liveService
              .sendMessage(
                streamId: _streamId!,
                userId: 'system',
                username: 'system',
                message: 'A viewer left the stream',
                type: ChatMessageType.system,
              )
              .catchError((_) {});
        },
        onTokenPrivilegeWillExpire: (connection, token) async {
          if (_streamId == null) return;
          try {
            final newToken = await _tokenService.renewToken(
              channelName: _streamId!,
              uid: _localUid,
              isHost: true,
            );
            await _engine.renewToken(newToken);
          } catch (_) {
            _showToast('Token renewal failed — stream may disconnect');
          }
        },
        onError: (err, msg) {
          if (!mounted) return;
          _showToast('Stream error: $msg');
        },
      ),
    );

    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine.enableVideo();
    await _engine.enableAudio();
    await _engine.startPreview();

    if (!mounted) return;
    setState(() {
      _engineReady = true;
      _engineVersion++;
      _liveState = _LiveState.offline;
    });
  }

  // ── Actions ───────────────────────────────────────────────────────────────────

  void _startCountdown() {
    setState(() {
      _liveState = _LiveState.countdown;
      _countdown = 3;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_countdown <= 1) {
        t.cancel();
        await _goLive();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    setState(() => _liveState = _LiveState.offline);
  }

  Future<void> _goLive() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showToast('Not signed in');
      setState(() => _liveState = _LiveState.offline);
      return;
    }

    try {
      // Load user profile for display name
      final profile = await _userService.getUser(user.uid);
      final username =
          profile?.username ?? user.email?.split('@').first ?? 'Host';
      final profileImage = profile?.profileImage;

      // Create Firestore document — channel name = doc ID
      final streamId = await _liveService.createStream(
        hostId: user.uid,
        hostUsername: username,
        hostProfileImage: profileImage,
        title: _streamTitle.isEmpty ? 'Live Stream' : _streamTitle,
        description: _streamDescription,
        category: _streamCategory,
        tags: _streamTags,
        pricePerMinute: _streamPrice,
        // Tag the feed as 360 when broadcasting the Insta360 (equirectangular),
        // so the viewer can detect it and route to the interactive 360 player.
        video360: _cameraSource == _CameraSource.insta360
            ? const Video360Metadata(
                is360Video: true,
                projectionType: Video360Projection.equirectangular,
                stereoMode: Video360StereoMode.mono,
              )
            : Video360Metadata.flat,
        isVR: _cameraSource == _CameraSource.insta360,
      );
      _streamId = streamId;

      // Fetch a signed token from the Cloud Function
      final token = await _tokenService.getToken(
        channelName: streamId,
        uid: 0,
        isHost: true,
      );

      // Join Agora channel as broadcaster
      await _engine.joinChannel(
        token: token,
        channelId: streamId,
        uid: 0,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: false,
          autoSubscribeVideo: false,
        ),
      );

      // Subscribe to real-time updates
      _streamSub = _liveService.streamDoc(streamId).listen((doc) {
        if (mounted && doc != null) setState(() => _streamDoc = doc);
      });
      _chatSub = _liveService.chatMessages(streamId).listen((msgs) {
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

      // Send join system message
      await _liveService.sendMessage(
        streamId: streamId,
        userId: user.uid,
        username: username,
        message: 'Stream started 🎬',
        type: ChatMessageType.system,
      );

      if (!mounted) return;
      setState(() => _liveState = _LiveState.live);
      // Send heartbeat immediately, then every 30 s so discover list stays current
      _liveService.updateHeartbeat(_streamId!).ignore();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_streamId != null) {
          _liveService.updateHeartbeat(_streamId!).ignore();
        }
      });
    } catch (e, st) {
      debugPrint('❌ _goLive error: $e\n$st');
      if (!mounted) return;
      _showToast('Failed to start stream: $e');
      setState(() => _liveState = _LiveState.offline);
    }
  }

  Future<void> _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    await _engine.muteLocalAudioStream(_isMuted);
    _showToast(_isMuted ? 'Live stream Muted' : 'Microphone on');
  }

  Future<void> _toggleVideo() async {
    setState(() => _isVideoOff = !_isVideoOff);
    await _engine.muteLocalVideoStream(_isVideoOff);
    if (_isVideoOff) _showToast('Video turned off');
  }

  void _toggleComments() {
    setState(() => _isCommentsOff = !_isCommentsOff);
    if (_isCommentsOff) _showToast('Comments turned off');
  }

  Future<void> _flipCamera() async {
    await _engine.switchCamera();
    setState(() => _isFrontCamera = !_isFrontCamera);
  }

  // ── Camera source switching (phone ↔ Insta360 360°) ───────────────────────────

  /// Opens the "Select camera" sheet.
  Future<void> _openCameraPicker() async {
    if (!_engineReady || _insta360Switching) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A0A1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => _CameraPickerSheet(
        current: _cameraSource,
        insta360Supported: _insta360Supported,
        onSelectPhone: () {
          Navigator.of(sheetCtx).pop();
          if (_cameraSource == _CameraSource.insta360) _disableInsta360();
        },
        onSelectInsta360: (type) {
          Navigator.of(sheetCtx).pop();
          if (_cameraSource == _CameraSource.phone) _enableInsta360(type);
        },
      ),
    );
  }

  Future<void> _enableInsta360(Insta360ConnectType type) async {
    if (_insta360Switching) return;
    setState(() => _insta360Switching = true);
    try {
      // BLE discovery + connect permissions (Wi-Fi/USB control both rely on these on 12+).
      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();

      final ok = await _insta.connect(type);
      if (!ok) {
        // Surfaces the native reason, e.g. "Join the camera's Wi-Fi … in Settings, then try again."
        _showToast(_insta.state.value.lastError ?? 'Could not connect to the 360 camera');
        return;
      }

      // Route the Insta360 ERP frames into Agora as the video source instead of the phone camera.
      await _engine.stopPreview();
      await _engine.getMediaEngine().setExternalVideoSource(
            enabled: true,
            useTexture: false,
            sourceType: ExternalVideoSourceType.videoFrame,
          );
      _instaFrameSub = _insta.frames().listen(_pushInstaFrame);
      await _insta.setFrameStreaming(true);

      if (!mounted) return;
      // openCamera() is async: the ERP preview only mounts once the connection event arrives
      // (see _onInstaState → _buildBackground). Until then show a "connecting" state, and arm a
      // timeout so a camera that never opens falls back to the phone instead of hanging.
      _instaWasConnected = false;
      _instaConnectTimer?.cancel();
      _instaConnectTimer = Timer(const Duration(seconds: 15), () {
        if (mounted &&
            _cameraSource == _CameraSource.insta360 &&
            !_insta.state.value.connected) {
          _showToast(_insta.state.value.lastError ??
              '360 camera didn’t start — check it’s on and connected via USB');
          _disableInsta360();
        }
      });
      setState(() => _cameraSource = _CameraSource.insta360);
      _showToast('Connecting to 360 camera…');
    } catch (e) {
      _showToast('360 switch failed: $e');
      await _disableInsta360();
    } finally {
      if (mounted) setState(() => _insta360Switching = false);
    }
  }

  Future<void> _disableInsta360() async {
    _instaConnectTimer?.cancel();
    _instaWasConnected = false;
    try {
      await _insta.setFrameStreaming(false);
    } catch (_) {}
    await _instaFrameSub?.cancel();
    _instaFrameSub = null;
    try {
      await _engine.getMediaEngine().setExternalVideoSource(
            enabled: false,
            useTexture: false,
            sourceType: ExternalVideoSourceType.videoFrame,
          );
      await _insta.disconnect();
      await _engine.startPreview(); // resume phone camera preview
    } catch (_) {}
    if (mounted) setState(() => _cameraSource = _CameraSource.phone);
  }

  /// Host drag on the 360 preview → look around. Accumulates yaw/pitch and pushes the absolute
  /// orientation to the SDK player. (Vertical works; horizontal is reliably done via the slider,
  /// since the OS steals horizontal touch swipes — see [_onJogStart].)
  void _onPreviewDrag(Offset delta) {
    _viewYaw += delta.dx * _kDragDegPerPx;
    _viewPitch = (_viewPitch - delta.dy * _kDragDegPerPx).clamp(-89.0, 89.0);
    _insta.setViewOrientation(_viewYaw, _viewPitch);
  }

  /// Finger down on the jog slider: start the ticker that rotates yaw while held off-centre.
  void _onJogStart() {
    _jogActive = true;
    _jogTimer ??= Timer.periodic(const Duration(milliseconds: 40), (_) {
      // Small dead zone near centre; beyond it rotate at a CONSTANT slow rate (direction only).
      // Negative so the view follows the slider direction (slide right → view pans right).
      if (!_jogActive || _jogYaw.abs() < 0.08) return;
      _viewYaw -= _jogYaw.sign * _kJogStepDeg;
      _insta.setViewOrientation(_viewYaw, _viewPitch);
    });
  }

  /// Jog slider moved: just record the deflection (the ticker reads it).
  void _onJogChanged(double v) {
    setState(() => _jogYaw = v);
  }

  /// Finger off the jog slider: stop rotating and spring the thumb back to centre (view holds).
  void _onJogEnd() {
    _jogActive = false;
    _jogTimer?.cancel();
    _jogTimer = null;
    setState(() => _jogYaw = 0.0);
  }

  /// Toggle forward-only masking on the live 360 feed (masked ↔ full 360°).
  Future<void> _toggleMask() async {
    setState(() => _maskEnabled = !_maskEnabled);
    await _insta.setMaskEnabled(_maskEnabled);
    _showToast(_maskEnabled ? 'Forward mask on' : 'Full 360° (unmasked)');
  }

  void _pushInstaFrame(Insta360Frame frame) {
    if (_cameraSource != _CameraSource.insta360) return;
    _engine
        .getMediaEngine()
        .pushVideoFrame(
          frame: ExternalVideoFrame(
            type: VideoBufferType.videoBufferRawData,
            format: VideoPixelFormat.videoPixelRgba,
            buffer: frame.bytes,
            stride: frame.width,
            height: frame.height,
            timestamp: frame.ptsUs ~/ 1000,
          ),
        )
        .catchError((_) {});
  }

  Future<void> _sendChatMessage() async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty || _streamId == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _chatCtrl.clear();
    try {
      await _liveService.sendMessage(
        streamId: _streamId!,
        userId: user.uid,
        username: _streamDoc?.hostUsername ?? 'Host',
        profileImage: _streamDoc?.hostProfileImage,
        message: text,
      );
    } catch (e) {
      _showToast('Failed to send');
    }
  }

  Future<void> _sendLike() async {
    if (_streamId == null) return;
    try {
      await _liveService.addLike(_streamId!);
    } catch (_) {}
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _LiveSettingsSheet(
          initialTitle: _streamTitle,
          initialDescription: _streamDescription,
          initialCategory: _streamCategory,
          initialTags: _streamTags,
          initialPrice: _streamPrice,
          isLive: _liveState == _LiveState.live,
          onSave: (title, desc, category, tags, price) async {
            setState(() {
              _streamTitle = title;
              _streamDescription = desc;
              _streamCategory = category;
              _streamTags = tags;
              _streamPrice = price;
            });
            if (_liveState == _LiveState.live && _streamId != null) {
              await _liveService.updateStreamMetadata(
                streamId: _streamId!,
                title: title,
                description: desc,
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _onEndStream() async {
    final end = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (_) => const _ConfirmDialog(
        message: 'Do you want to end this live stream?',
        confirmLabel: 'Yes, End',
      ),
    );
    if (end != true || !mounted) return;

    // End the stream
    if (_streamId != null) {
      await _engine.leaveChannel();
      await _liveService.endStream(_streamId!, savedToProfile: false);
    }

    if (!mounted) return;
    final save = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (_) => const _ConfirmDialog(
        message: 'Do you want to add this live stream to your profile?',
        confirmLabel: 'Yes, Add',
      ),
    );

    if (save == true && _streamId != null) {
      await _liveService.endStream(_streamId!, savedToProfile: true);
    }

    if (mounted) Navigator.of(context).pop();
  }

  /// Same **Story | Post | Live** row as [UploadScreen] (+ hub); Live is selected here.
  Widget _createHubBottomBar() {
    return UploadCreateBottomBar(
      selectedSegment: 2,
      onStoryTap: () {
        Navigator.of(context).pushReplacement<void, void>(
          MaterialPageRoute<void>(
            builder: (_) => const StoryUploadScreen(),
          ),
        );
      },
      onPostTap: () {
        Navigator.of(context).pushReplacement<void, void>(
          MaterialPageRoute<void>(
            builder: (_) => const UploadScreen(initialBottomSegment: 1),
          ),
        );
      },
      onLiveTap: () {},
    );
  }

  void _showToast(String msg) {
    setState(() => _toast = msg);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(),
          _buildGradientOverlay(),
          _buildStateContent(),
          if (_cameraSource == _CameraSource.insta360 && _insta.state.value.connected)
            _build360LookControls(),
          if (_toast != null) _buildToast(_toast!),
        ],
      ),
    );
  }

  /// Top-layer look-around controls for the 360 view. Must sit above [_buildStateContent] —
  /// widgets placed in the background layer receive no touch events on this screen.
  Widget _build360LookControls() {
    return Stack(
      children: [
        // Drag-to-look: a central catcher in this TOP layer (background-layer gestures get no
        // touches here). Inset to leave the right-column controls and bottom bar tappable.
        Positioned(
          top: 220,
          left: 0,
          right: 150,
          bottom: 560,
          // Listener (raw pointer events), not GestureDetector: an ancestor horizontal-drag
          // recognizer wins the gesture arena and eats horizontal pans, but raw pointer events
          // still flow to every Listener in the hit path — so this captures drags in both axes.
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerMove: (e) => _onPreviewDrag(e.delta),
          ),
        ),
        // Horizontal rotation jog slider — sits above the Start Live button. Hold the thumb
        // left/right to rotate the 360 view at a constant slow rate; release and it springs back
        // to centre while the view keeps its angle.
        Positioned(
          left: 20,
          right: 20,
          bottom: 170,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              children: [
                const Icon(Icons.chevron_left, color: Colors.white70, size: 22),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 16),
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 10),
                    ),
                    child: Slider(
                      value: _jogYaw,
                      min: -1.0,
                      max: 1.0,
                      onChangeStart: (_) => _onJogStart(),
                      onChanged: _onJogChanged,
                      onChangeEnd: (_) => _onJogEnd(),
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white70, size: 22),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Small "360 • Wi-Fi/USB" badge shown while the Insta360 is the active source.
  Widget _source360Chip() {
    if (_cameraSource != _CameraSource.insta360) return const SizedBox.shrink();
    final via = _insta.state.value.connectType == 1 ? 'USB' : 'Wi-Fi';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.threesixty_rounded, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            '360 • $via',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    if (!_engineReady) return Container(color: const Color(0xFF0A000F));
    if (_isVideoOff && _liveState == _LiveState.live) {
      return Container(color: const Color(0xFF0A000F));
    }
    // 360° source: the host previews the SDK's interactive sphere directly — touch-drag to look
    // around, pinch to zoom. Remote viewers receive the extracted ERP frames pushed via
    // [_pushInstaFrame]. The preview is mounted only once the camera is actually connected —
    // mounting it earlier would start the preview stream before the camera session exists.
    if (_cameraSource == _CameraSource.insta360) {
      if (_insta.state.value.connected) {
        // Just the render here; the look-around controls live in the TOP layer (see
        // _build360LookControls) because anything in this background layer receives no touches.
        return const Insta360PreviewView(extractWidth: 1920, extractHeight: 960);
      }
      return const ColoredBox(
        color: Color(0xFF0A000F),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Connecting to 360 camera…',
                  style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }
    return AgoraVideoView(
      key: ValueKey(_engineVersion),
      controller: VideoViewController(
        rtcEngine: _engine,
        canvas: const VideoCanvas(uid: 0), // 0 = always local video
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

  Widget _buildStateContent() {
    return switch (_liveState) {
      _LiveState.initializing => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      _LiveState.permissionDenied => _buildPermissionDenied(),
      _LiveState.offline => _buildOfflineContent(),
      _LiveState.countdown => _buildCountdownContent(),
      _LiveState.live => _buildLiveContent(),
    };
  }

  // ── Permission denied ──────────────────────────────────────────────────────────

  Widget _buildPermissionDenied() {
    return SafeArea(
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.videocam_off_rounded,
                    color: Colors.white54,
                    size: 64,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Camera & microphone access is required to go live.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _GradientButton(
                    label: 'Open Settings',
                    icon: Icons.settings_rounded,
                    onTap: () => openAppSettings(),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _createHubBottomBar(),
          ),
        ],
      ),
    );
  }

  // ── Offline state ──────────────────────────────────────────────────────────────

  Widget _buildOfflineContent() {
    return SafeArea(
      child: Stack(
        children: [
          // Close
          Positioned(
            top: 6,
            left: 10,
            child: _CircleIconButton(
              icon: Icons.close,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          // OFFLINE badge
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'OFFLINE',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  _source360Chip(),
                ],
              ),
            ),
          ),
          // Right tool icons
          Positioned(
            top: 100,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CircleIconButton(
                    icon: Icons.threesixty_rounded,
                    onTap: _openCameraPicker,
                    active: _cameraSource == _CameraSource.insta360,
                    size: 38,
                  ),
                  // Masked (forward-only) ↔ full 360° toggle — only for the 360 feed.
                  if (_cameraSource == _CameraSource.insta360)
                    _CircleIconButton(
                      icon: _maskEnabled
                          ? Icons.vignette
                          : Icons.panorama_horizontal_rounded,
                      onTap: _toggleMask,
                      active: _maskEnabled,
                      size: 38,
                    ),
                  _CircleIconButton(
                    icon: Icons.mic_none_rounded,
                    onTap: _toggleMute,
                    size: 38,
                  ),
                  _CircleIconButton(
                    icon: Icons.videocam_outlined,
                    onTap: _toggleVideo,
                    size: 38,
                  ),
                  // Flip (front/back) only applies to the phone camera.
                  if (_cameraSource == _CameraSource.phone)
                    _CircleIconButton(
                      icon: Icons.refresh_rounded,
                      onTap: _flipCamera,
                      size: 38,
                    ),
                  _CircleIconButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    onTap: _toggleComments,
                    size: 38,
                  ),
                  _CircleIconButton(
                    icon: Icons.settings_outlined,
                    onTap: _openSettings,
                    size: 38,
                  ),
                ],
              ),
            ),
          ),
          // Bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_streamTitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _streamTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 8,
                  ),
                  child: _GradientButton(
                    label: 'Start Live',
                    icon: Icons.sensors_rounded,
                    onTap: _startCountdown,
                    isWhite: true,
                  ),
                ),
                _createHubBottomBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Countdown state ────────────────────────────────────────────────────────────

  Widget _buildCountdownContent() {
    return SafeArea(
      child: Stack(
        children: [
          // Background overlay for countdown
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.35)),
          ),
          Positioned(
            top: 14,
            left: 48,
            right: 48,
            child: Text(
              _streamTitle.isEmpty ? 'Going Live...' : _streamTitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Center(
            child: SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                children: [
                  CustomPaint(
                    size: const Size(96, 96),
                    painter: _CountdownCirclePainter(),
                  ),
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.35),
                      ),
                      child: Center(
                        child: Text(
                          '$_countdown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _createHubBottomBar(),
                Container(
                  height: 100,
                  color: const Color(0xFF490038), // brandPurple/Plum bar
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Center(
                    child: GestureDetector(
                      onTap: _cancelCountdown,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.close, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Live state ─────────────────────────────────────────────────────────────────

  Widget _buildLiveContent() {
    final viewers = _streamDoc?.viewerCount ?? 0;
    final likes = _streamDoc?.likeCount ?? 0;

    return SafeArea(
      child: Stack(
        children: [
          // Top: LIVE badge + title
          Positioned(
            top: 12,
            left: 16,
            right: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  backgroundImage: _streamDoc?.hostProfileImage != null
                      ? NetworkImage(_streamDoc!.hostProfileImage!)
                      : null,
                  child: _streamDoc?.hostProfileImage == null
                      ? const Icon(Icons.person, color: Colors.white, size: 20)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _streamTitle.isEmpty ? 'Live Stream Topic' : _streamTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _source360Chip(),
              ],
            ),
          ),
          Positioned(
            top: 100,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CircleIconButton(
                    icon: Icons.threesixty_rounded,
                    onTap: _openCameraPicker,
                    active: _cameraSource == _CameraSource.insta360,
                    size: 38,
                  ),
                  // Masked (forward-only) ↔ full 360° toggle — only for the 360 feed.
                  if (_cameraSource == _CameraSource.insta360)
                    _CircleIconButton(
                      icon: _maskEnabled
                          ? Icons.vignette
                          : Icons.panorama_horizontal_rounded,
                      onTap: _toggleMask,
                      active: _maskEnabled,
                      size: 38,
                    ),
                  _CircleIconButton(
                    icon: _isMuted
                        ? Icons.mic_off_outlined
                        : Icons.mic_none_rounded,
                    onTap: _toggleMute,
                    active: _isMuted,
                    size: 38,
                  ),
                  _CircleIconButton(
                    icon: _isVideoOff
                        ? Icons.videocam_off_outlined
                        : Icons.videocam_outlined,
                    onTap: _toggleVideo,
                    active: _isVideoOff,
                    size: 38,
                  ),
                  // Flip (front/back) only applies to the phone camera.
                  if (_cameraSource == _CameraSource.phone)
                    _CircleIconButton(
                      icon: Icons.refresh_rounded,
                      onTap: _flipCamera,
                      size: 38,
                    ),
                  _CircleIconButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    onTap: _toggleComments,
                    active: _isCommentsOff,
                    size: 38,
                  ),
                  _CircleIconButton(
                    icon: Icons.settings_outlined,
                    onTap: _openSettings,
                    size: 38,
                  ),
                ],
              ),
            ),
          ),
          if (_isCommentsOff)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Comments turned off',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          // Bottom: chat + input + end button (inset) + create hub bar (full bleed, matches + Post)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildChatList(),
                        const SizedBox(height: 8),
                        _buildCommentRow(likes, viewers),
                        const SizedBox(height: 10),
                        _buildEndStreamButton(),
                      ],
                    ),
                  ),
                  _createHubBottomBar(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    final msgs = _isCommentsOff
        ? const <LiveChatMessageModel>[]
        : _chatMessages;
    if (msgs.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.2)],
        ),
      ),
      constraints: const BoxConstraints(maxHeight: 180),
      child: ListView.builder(
        controller: _chatScrollCtrl,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: msgs.length,
        itemBuilder: (context, i) {
          final m = msgs[i];
          final isSystem = m.type == ChatMessageType.system;
          if (isSystem) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Center(
                child: Text(
                  m.message,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
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
                  backgroundImage: (m.profileImage?.isNotEmpty == true)
                      ? NetworkImage(m.profileImage!)
                      : null,
                  child: (m.profileImage?.isNotEmpty != true)
                      ? Text(
                          m.username[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        )
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: m.message,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
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

  Widget _buildCommentRow(int likes, int viewers) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _chatCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendChatMessage(),
              decoration: InputDecoration(
                hintText: 'Reply...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Views
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.remove_red_eye_outlined,
              color: Colors.white.withValues(alpha: 0.7),
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              _formatCount(viewers),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        // Likes
        GestureDetector(
          onTap: _sendLike,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite, color: Colors.pink, size: 16),
              const SizedBox(width: 4),
              Text(
                _formatCount(likes),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEndStreamButton() {
    return Center(
      child: GestureDetector(
        onTap: _onEndStream,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'End stream',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToast(String msg) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          msg,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? AppColors.brandPink.withValues(alpha: 0.35)
              : Colors.transparent,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isWhite = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isWhite;

  @override
  Widget build(BuildContext context) {
    final iconColor = isWhite ? AppColors.brandPink : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: isWhite ? Colors.white : null,
          gradient: isWhite
              ? null
              : const LinearGradient(
                  colors: [Color(0xFFDE106B), Color(0xFFF81945)],
                ),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: isWhite ? Colors.black : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeartSliderThumb extends SliderComponentShape {
  final double thumbRadius;

  const _HeartSliderThumb({this.thumbRadius = 14.0});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size.fromRadius(thumbRadius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    final paint = Paint()
      ..color = const Color(0xFFF81945)
      ..style = PaintingStyle.fill;

    // Heart-like badge shape
    const double r = 10.0;
    final path = Path();
    path.moveTo(center.dx, center.dy + r);
    path.cubicTo(
      center.dx - r * 1.5,
      center.dy - r * 0.5,
      center.dx - r * 0.8,
      center.dy - r * 1.8,
      center.dx,
      center.dy - r * 0.8,
    );
    path.cubicTo(
      center.dx + r * 0.8,
      center.dy - r * 1.8,
      center.dx + r * 1.5,
      center.dy - r * 0.5,
      center.dx,
      center.dy + r,
    );
    canvas.drawPath(path, paint);

    // Text inside badge (e.g. C7)
    final val = (value * 10).round();
    final tp = TextPainter(
      text: TextSpan(
        text: 'C$val',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: textDirection,
    );
    tp.layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2 + 2));
  }
}

class _CountdownCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // 1. Solid part (approx 1/3 of circle)
    final solidPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -2.2, // Start at approx 10 o'clock
      2.1, // Sweep approx 120 degrees
      false,
      solidPaint,
    );

    // 2. Dashed part
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const double dashLen = 6;
    const double spaceLen = 6;
    double startAngle = -0.1; // Start where solid part ends
    const double endAngle = 4.0; // End where solid part begins again (looping)

    // Rough loop to draw dashes for the remaining arc
    while (startAngle < endAngle) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashLen / radius,
        false,
        dashPaint,
      );
      startAngle += (dashLen + spaceLen) / radius;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Confirm dialog ─────────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({required this.message, required this.confirmLabel});

  final String message;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        decoration: BoxDecoration(
          color: const Color(0xFF2E0D2E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'VyooO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(true),
                  child: Text(
                    confirmLabel,
                    style: const TextStyle(
                      color: AppColors.brandPink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'No',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Camera-source picker sheet ─────────────────────────────────────────────────

/// "Select camera" bottom sheet: phone camera vs Insta360 (360°, USB by default; Wi-Fi optional).
class _CameraPickerSheet extends StatelessWidget {
  const _CameraPickerSheet({
    required this.current,
    required this.insta360Supported,
    required this.onSelectPhone,
    required this.onSelectInsta360,
  });

  final _CameraSource current;
  final bool insta360Supported;
  final VoidCallback onSelectPhone;
  final void Function(Insta360ConnectType type) onSelectInsta360;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8, left: 4),
              child: Text(
                'Select camera',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // Phone camera
            _tile(
              icon: Icons.smartphone_rounded,
              title: 'Phone camera',
              subtitle: 'Built-in front/back camera',
              selected: current == _CameraSource.phone,
              enabled: true,
              onTap: onSelectPhone,
            ),
            const SizedBox(height: 8),
            // Insta360 360°
            _tile(
              icon: Icons.threesixty_rounded,
              title: 'Insta360 (360°)',
              subtitle: insta360Supported
                  ? 'Stitched panoramic feed'
                  : 'Requires an arm64 device (Android 10+)',
              selected: current == _CameraSource.insta360,
              enabled: insta360Supported,
              onTap: insta360Supported
                  ? () => onSelectInsta360(Insta360ConnectType.usb)
                  : null,
            ),
            if (insta360Supported) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text(
                  'Connect the camera to the phone with a USB cable, then tap USB. '
                  '(Wi-Fi also works but disables the phone\'s internet while live.)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _connectButton(
                      icon: Icons.usb_rounded,
                      label: 'USB',
                      onTap: () => onSelectInsta360(Insta360ConnectType.usb),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _connectButton(
                      icon: Icons.wifi_rounded,
                      label: 'Wi-Fi',
                      onTap: () => onSelectInsta360(Insta360ConnectType.wifi),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: selected ? 0.12 : 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.brandPink : Colors.white12,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.brandPink, size: 20)
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _connectButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Settings bottom sheet ──────────────────────────────────────────────────────

typedef _SettingsSaveCallback =
    void Function(
      String title,
      String description,
      String category,
      List<String> tags,
      int pricePerMinute,
    );

class _LiveSettingsSheet extends StatefulWidget {
  const _LiveSettingsSheet({
    required this.initialTitle,
    required this.initialDescription,
    required this.initialCategory,
    required this.initialTags,
    required this.initialPrice,
    required this.isLive,
    required this.onSave,
  });

  final String initialTitle;
  final String initialDescription;
  final String initialCategory;
  final List<String> initialTags;
  final int initialPrice;
  final bool isLive;
  final _SettingsSaveCallback onSave;

  @override
  State<_LiveSettingsSheet> createState() => _LiveSettingsSheetState();
}

class _LiveSettingsSheetState extends State<_LiveSettingsSheet> {
  static const _titleMax = 120;
  static const _descMax = 200;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  final TextEditingController _tagsCtrl = TextEditingController();

  late String _selectedCategory;
  late List<String> _tags;
  late double _priceLevel;

  static const _categories = [
    'Entertainment',
    'Music',
    'Sports',
    'Gaming',
    'Education',
    'Fitness',
    'Travel',
    'Food',
    'Art',
    'Technology',
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _descCtrl = TextEditingController(text: widget.initialDescription);
    _selectedCategory = widget.initialCategory;
    _tags = List.from(widget.initialTags);
    _priceLevel = widget.initialPrice.toDouble().clamp(0, 7);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(
      _titleCtrl.text.trim(),
      _descCtrl.text.trim(),
      _selectedCategory,
      _tags,
      _priceLevel.round(),
    );
    Navigator.of(context).pop();
  }

  void _addTag(String raw) {
    final tag = raw.trim();
    if (tag.isEmpty || _tags.length >= 8 || _tags.contains(tag)) return;
    setState(() => _tags.add(tag));
    _tagsCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType.premiumDark,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.chevron_left_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Stream Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _save,
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          color: AppColors.brandMagenta,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Form
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    _buildField(
                      'Title',
                      _titleCtrl,
                      _titleMax,
                      'Add your Title',
                      1,
                    ),
                    const SizedBox(height: 24),
                    _buildField(
                      'Description',
                      _descCtrl,
                      _descMax,
                      'Add a short description',
                      3,
                    ),
                    const SizedBox(height: 24),
                    _buildCategoryDropdown(),
                    const SizedBox(height: 24),
                    _buildTagsField(),
                    // Pricing only editable pre-live
                    if (!widget.isLive) ...[
                      const SizedBox(height: 24),
                      _buildPricingSlider(),
                    ],
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl,
    int maxLength,
    String hint,
    int maxLines,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: ctrl,
              builder: (context, v, child) => Text(
                '${v.text.length}/$maxLength',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        TextField(
          controller: ctrl,
          maxLength: maxLength,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 13,
            ),
            border: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24, width: 0.8),
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24, width: 0.8),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFDE106B), width: 1.2),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            counterText: '',
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedCategory.isEmpty ? null : _selectedCategory,
            hint: Text(
              'Select your category',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 13,
              ),
            ),
            isExpanded: true,
            dropdownColor: const Color(0xFF2A1030),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white.withValues(alpha: 0.6),
              size: 20,
            ),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            items: _categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _selectedCategory = v ?? ''),
          ),
        ),
        const Divider(color: Colors.white24, height: 1, thickness: 0.8),
        const SizedBox(height: 8),
        Text(
          'Adding a category helps others find your content in search.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildTagsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tags',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${_tags.length}/6',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          ],
        ),
        TextField(
          controller: _tagsCtrl,
          enabled: _tags.length < 6,
          onSubmitted: _addTag,
          textInputAction: TextInputAction.done,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Enter your own tags',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 13,
            ),
            border: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24, width: 0.8),
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24, width: 0.8),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFDE106B), width: 1.2),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            counterText: '',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tags are visible by others and are used to make you discoverable on Vyooo.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
          ),
        ),
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _tags.map((t) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => setState(() => _tags.remove(t)),
                      child: Icon(
                        Icons.close,
                        color: Colors.white.withValues(alpha: 0.6),
                        size: 14,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildPricingSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Live video pricing',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Set your per-minute rate for non-subscribers',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFFDE106B),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
            thumbShape: const _HeartSliderThumb(thumbRadius: 16),
            overlayColor: const Color(0xFFDE106B).withValues(alpha: 0.1),
            trackHeight: 2,
          ),
          child: Slider(
            value: _priceLevel,
            min: 0,
            max: 10,
            divisions: 10,
            onChanged: (v) => setState(() => _priceLevel = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [0, 2, 4, 6, 8, 10]
                .map(
                  (i) => Text(
                    '$i',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
