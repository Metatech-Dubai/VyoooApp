import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/models/story_highlight_model.dart';
import '../../core/services/story_service.dart';

/// Swipe through saved highlight items (persists beyond 24h story expiry).
class HighlightViewerScreen extends StatefulWidget {
  const HighlightViewerScreen({
    super.key,
    required this.userId,
    required this.highlightId,
    required this.title,
  });

  final String userId;
  final String highlightId;
  final String title;

  @override
  State<HighlightViewerScreen> createState() => _HighlightViewerScreenState();
}

class _HighlightViewerScreenState extends State<HighlightViewerScreen> {
  List<StoryHighlightItem> _items = [];
  bool _loading = true;
  String? _error;
  int _index = 0;
  VideoPlayerController? _video;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await StoryService().getHighlightItems(
        userId: widget.userId,
        highlightId: widget.highlightId,
      );
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
      if (list.isNotEmpty) {
        await _prepareMediaForIndex(0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _prepareMediaForIndex(int i) async {
    await _video?.dispose();
    _video = null;
    if (i < 0 || i >= _items.length) return;
    final it = _items[i];
    if (!it.isVideo || it.mediaUrl.isEmpty) {
      if (mounted) setState(() {});
      return;
    }
    final uri = Uri.tryParse(it.mediaUrl);
    if (uri == null || !uri.hasScheme) return;
    final c = VideoPlayerController.networkUrl(uri);
    await c.initialize();
    if (!mounted) return;
    setState(() {
      _video = c..play();
    });
  }

  void _next() {
    if (_index >= _items.length - 1) return;
    setState(() => _index++);
    _prepareMediaForIndex(_index);
  }

  void _prev() {
    if (_index <= 0) return;
    setState(() => _index--);
    _prepareMediaForIndex(_index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.white70),
                  ),
                )
              : _items.isEmpty
                  ? const Center(
                      child: Text(
                        'No items in this highlight yet.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : GestureDetector(
                      onTapUp: (d) {
                        final w = MediaQuery.sizeOf(context).width;
                        if (d.globalPosition.dx < w / 2) {
                          _prev();
                        } else {
                          _next();
                        }
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Center(child: _buildMedia(_items[_index])),
                          if (_items[_index].caption.isNotEmpty)
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 32,
                              child: Text(
                                _items[_index].caption,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  shadows: [
                                    Shadow(color: Colors.black54, blurRadius: 8),
                                  ],
                                ),
                              ),
                            ),
                          Positioned(
                            top: 8,
                            left: 0,
                            right: 0,
                            child: Text(
                              '${_index + 1} / ${_items.length}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildMedia(StoryHighlightItem it) {
    if (it.isVideo) {
      final v = _video;
      if (v == null || !v.value.isInitialized) {
        return const CircularProgressIndicator(color: Colors.white54);
      }
      return AspectRatio(
        aspectRatio:
            v.value.aspectRatio == 0 ? 9 / 16 : v.value.aspectRatio,
        child: VideoPlayer(v),
      );
    }
    if (it.mediaUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    return Image.network(it.mediaUrl, fit: BoxFit.contain);
  }
}
