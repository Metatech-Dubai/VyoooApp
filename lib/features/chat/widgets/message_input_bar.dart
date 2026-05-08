import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_colors.dart';

enum MediaAction {
  galleryPhoto,
  galleryVideo,
  cameraPhoto,
  cameraVideo,
  viewOncePhoto,
  viewOnceVideo,
}

class MessageInputBar extends StatefulWidget {
  const MessageInputBar({
    super.key,
    required this.onSend,
    this.onMediaAction,
    this.mediaLoading = false,
    this.onTypingChanged,
    this.onVoiceNoteSend,
  });

  final void Function(String text) onSend;
  final void Function(MediaAction action)? onMediaAction;
  final bool mediaLoading;
  final void Function(bool isTyping)? onTypingChanged;
  final void Function(File file, int durationMs)? onVoiceNoteSend;

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  final TextEditingController _controller = TextEditingController();
  bool _canSend = false;
  bool _wasTyping = false;
  bool _showEmojiRow = false;

  bool _isRecording = false;
  RecorderController? _recorderController;

  String? _pendingFilePath;
  int _pendingDuration = 0;
  bool _isSendingVoice = false;

  static const List<String> _quickEmojis = [
    '😂',
    '❤️',
    '🔥',
    '👏',
    '😮',
    '😢',
    '😍',
    '👍',
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _canSend) setState(() => _canSend = hasText);
      if (hasText && !_wasTyping) {
        _wasTyping = true;
        widget.onTypingChanged?.call(true);
      } else if (!hasText && _wasTyping) {
        _wasTyping = false;
        widget.onTypingChanged?.call(false);
      }
    });
  }

  @override
  void dispose() {
    if (_wasTyping) widget.onTypingChanged?.call(false);
    _controller.dispose();
    _recorderController?.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    _wasTyping = false;
    widget.onTypingChanged?.call(false);
  }

  void _insertEmoji(String emoji) {
    final sel = _controller.selection;
    final text = _controller.text;
    final newText = text.replaceRange(
      sel.start < 0 ? text.length : sel.start,
      sel.end < 0 ? text.length : sel.end,
      emoji,
    );
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: (sel.start < 0 ? text.length : sel.start) + emoji.length,
      ),
    );
  }

  Future<void> _startRecording() async {
    if (widget.onVoiceNoteSend == null) return;
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
      }
      return;
    }
    _recorderController = RecorderController();
    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorderController!.record(path: path);
      setState(() => _isRecording = true);
    } catch (e) {
      debugPrint('[MessageInputBar] record error: $e');
      _recorderController?.dispose();
      _recorderController = null;
    }
  }

  Future<void> _stopRecording() async {
    if (_recorderController == null) return;
    try {
      final duration = _recorderController!.elapsedDuration.inMilliseconds;
      final path = await _recorderController!.stop();
      _recorderController!.dispose();
      _recorderController = null;
      setState(() {
        _isRecording = false;
        if (path != null && path.isNotEmpty && duration > 500) {
          _pendingFilePath = path;
          _pendingDuration = duration;
        } else if (path != null && path.isNotEmpty) {
          _pendingFilePath = path;
          _pendingDuration = duration > 0 ? duration : 1000;
        }
      });
    } catch (e) {
      debugPrint('[MessageInputBar] stop record error: $e');
      _recorderController?.dispose();
      _recorderController = null;
      setState(() => _isRecording = false);
    }
  }

  Future<void> _cancelRecording() async {
    if (_recorderController == null) return;
    try {
      await _recorderController!.stop();
    } catch (_) {}
    _recorderController?.dispose();
    _recorderController = null;
    setState(() => _isRecording = false);
    _discardPendingVoice();
  }

  void _sendPendingVoice() {
    if (_isSendingVoice) return;
    final path = _pendingFilePath;
    final dur = _pendingDuration;
    if (path == null || path.isEmpty || dur <= 0) return;
    setState(() => _isSendingVoice = true);
    widget.onVoiceNoteSend?.call(File(path), dur);
    setState(() {
      _pendingFilePath = null;
      _pendingDuration = 0;
      _isSendingVoice = false;
    });
  }

  void _discardPendingVoice() {
    final path = _pendingFilePath;
    if (path != null) {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
    setState(() {
      _pendingFilePath = null;
      _pendingDuration = 0;
    });
  }

  void _showMediaSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0A2E), Color(0xFF0D0518)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              _sheetTile(
                Icons.photo_library_outlined,
                'Photo from Gallery',
                MediaAction.galleryPhoto,
              ),
              _sheetTile(
                Icons.videocam_outlined,
                'Video from Gallery',
                MediaAction.galleryVideo,
              ),
              _sheetTile(
                Icons.camera_alt_outlined,
                'Take Photo',
                MediaAction.cameraPhoto,
              ),
              _sheetTile(
                Icons.videocam_outlined,
                'Record Video',
                MediaAction.cameraVideo,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  color: Colors.white.withValues(alpha: 0.08),
                  height: 1,
                ),
              ),
              _sheetTile(
                Icons.photo_camera_outlined,
                'View-once Photo',
                MediaAction.viewOncePhoto,
              ),
              _sheetTile(
                Icons.videocam_outlined,
                'View-once Video',
                MediaAction.viewOnceVideo,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetTile(IconData icon, String label, MediaAction action) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF2A1540),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
      onTap: () {
        Navigator.of(context).pop();
        widget.onMediaAction?.call(action);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPending = _pendingFilePath != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF10041A),
        border: Border(top: BorderSide(color: Color(0x33DE106B), width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasPending)
              _buildVoicePreviewRow()
            else if (_isRecording)
              _buildRecordingRow()
            else
              _buildInputRow(),
            if (_showEmojiRow && !_isRecording && !hasPending) _buildEmojiRow(),
          ],
        ),
      ),
    );
  }

  Future<void> _stopAndSend() async {
    if (_recorderController == null) return;
    try {
      final duration = _recorderController!.elapsedDuration.inMilliseconds;
      final path = await _recorderController!.stop();
      _recorderController!.dispose();
      _recorderController = null;
      setState(() => _isRecording = false);
      if (path != null && path.isNotEmpty) {
        final dur = duration > 0 ? duration : 1000;
        widget.onVoiceNoteSend?.call(File(path), dur);
      }
    } catch (e) {
      debugPrint('[MessageInputBar] stopAndSend error: $e');
      _recorderController?.dispose();
      _recorderController = null;
      setState(() => _isRecording = false);
    }
  }

  Widget _buildRecordingRow() {
    return Row(
      children: [
        GestureDetector(
          onTap: _cancelRecording,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.deleteRed.withValues(alpha: 0.15),
            ),
            child: const Icon(
              Icons.delete_outline,
              color: AppColors.deleteRed,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AudioWaveforms(
            recorderController: _recorderController!,
            size: const Size(double.infinity, 36),
            waveStyle: const WaveStyle(
              waveColor: AppColors.brandMagenta,
              extendWaveform: true,
              showMiddleLine: false,
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _stopRecording,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: const Icon(
              Icons.stop_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _stopAndSend,
          child: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFDE106B), Color(0xFF6B21A8)],
              ),
            ),
            child: const Icon(
              Icons.send_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }

  String _formatMs(int ms) {
    final s = (ms / 1000).floor();
    final m = (s / 60).floor().toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  Widget _buildVoicePreviewRow() {
    return Row(
      children: [
        GestureDetector(
          onTap: _discardPendingVoice,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.deleteRed.withValues(alpha: 0.15),
            ),
            child: const Icon(
              Icons.delete_outline,
              color: AppColors.deleteRed,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDE106B), Color(0xFFB80D5A)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 6),
                Expanded(child: _buildWaveformBars()),
                const SizedBox(width: 8),
                Text(
                  _formatMs(_pendingDuration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _isSendingVoice ? null : _sendPendingVoice,
          child: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFDE106B), Color(0xFF6B21A8)],
              ),
            ),
            child: _isSendingVoice
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildWaveformBars() {
    return CustomPaint(
      size: const Size(double.infinity, 20),
      painter: _WaveformBarsPainter(),
    );
  }

  Widget _buildInputRow() {
    return Row(
      children: [
        GestureDetector(
          onTap: widget.mediaLoading ? null : _showMediaSheet,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: widget.mediaLoading
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFFDE106B), Color(0xFFB80D5A)],
                    ),
              color: widget.mediaLoading ? const Color(0xFF2A1540) : null,
            ),
            child: Icon(
              Icons.camera_alt,
              color: widget.mediaLoading ? Colors.white24 : Colors.white,
              size: 16,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A0A2E),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x22DE106B), width: 0.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'Message...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                if (!_canSend && widget.onVoiceNoteSend != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: _startRecording,
                      child: Icon(
                        Icons.mic_none,
                        color: Colors.white.withValues(alpha: 0.4),
                        size: 22,
                      ),
                    ),
                  ),
                if (!_canSend)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: widget.mediaLoading ? null : _showMediaSheet,
                      child: Icon(
                        Icons.image_outlined,
                        color: Colors.white.withValues(alpha: 0.4),
                        size: 22,
                      ),
                    ),
                  ),
                GestureDetector(
                  onTap: () => setState(() => _showEmojiRow = !_showEmojiRow),
                  child: Icon(
                    Icons.emoji_emotions_outlined,
                    color: _showEmojiRow
                        ? AppColors.brandMagenta
                        : Colors.white.withValues(alpha: 0.4),
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (_canSend)
          GestureDetector(
            onTap: _handleSend,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFDE106B), Color(0xFF6B21A8)],
                ),
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmojiRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _quickEmojis.map((emoji) {
          return GestureDetector(
            onTap: () => _insertEmoji(emoji),
            child: Text(emoji, style: const TextStyle(fontSize: 26)),
          );
        }).toList(),
      ),
    );
  }
}

class _WaveformBarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const barSpacing = 4.0;
    final barCount = (size.width / barSpacing).floor();
    final mid = size.height / 2;

    for (var i = 0; i < barCount; i++) {
      final x = i * barSpacing + 1;
      final h =
          (((i * 7 + 3) % 11) / 11.0) * size.height * 0.8 + size.height * 0.15;
      canvas.drawLine(Offset(x, mid - h / 2), Offset(x, mid + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
