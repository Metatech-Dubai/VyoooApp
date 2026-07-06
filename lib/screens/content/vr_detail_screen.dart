import 'package:flutter/material.dart';

import '../../core/models/video_360_metadata.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/video_upload_policy.dart';
import '../../core/widgets/vyooo_360_video_player.dart';

/// Payload for opening VR full-screen view (from profile VR grid or search).
class VRDetailPayload {
  const VRDetailPayload({
    this.title = 'VR',
    this.videoUrl,
    this.thumbnailUrl = '',
    this.creatorName = 'Creator',
    this.creatorHandle = '',
    this.avatarUrl = '',
    this.description = '',
    this.likeCount = 0,
    this.commentCount = 0,
    this.viewCount = 0,
    this.shareCount = 0,
    this.saveCount = 0,
    this.video360 = Video360Metadata.flat,
  });

  final String title;
  final String? videoUrl;
  final String thumbnailUrl;
  final String creatorName;
  final String creatorHandle;
  final String avatarUrl;
  final String description;
  final int likeCount;
  final int commentCount;
  final int viewCount;
  final int shareCount;
  final int saveCount;
  final Video360Metadata video360;

  bool get hasPlayableVideo =>
      VideoUploadPolicy.isPlayableUrl((videoUrl ?? '').trim());
}

/// Full-screen VR view with immersive 360 playback when available.
class VRDetailScreen extends StatefulWidget {
  const VRDetailScreen({super.key, this.payload});

  final VRDetailPayload? payload;

  @override
  State<VRDetailScreen> createState() => _VRDetailScreenState();
}

class _VRDetailScreenState extends State<VRDetailScreen>
    with WidgetsBindingObserver {
  bool _showOverlay = false;
  bool _showInstruction = true;
  bool _isAppForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showInstruction = false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _isAppForeground) return;
    setState(() => _isAppForeground = foreground);
  }

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  Widget _buildInstructionOverlay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: const Text(
        'Drag to look around • Move device to explore',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMediaFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A1A), Color(0xFF050505)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.vrpano_outlined, color: Colors.white38, size: 56),
      ),
    );
  }

  Widget _buildBackgroundMedia(VRDetailPayload p) {
    final url = (p.videoUrl ?? '').trim();
    if (p.hasPlayableVideo) {
      return Vyooo360VideoPlayer(
        videoUrl: url,
        isVisible: _isAppForeground,
        video360: p.video360,
        thumbnailUrl: p.thumbnailUrl,
        enableGyro: true,
        enableTouch: true,
      );
    }
    if (p.thumbnailUrl.trim().isNotEmpty) {
      return Image.network(
        p.thumbnailUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildMediaFallback(),
      );
    }
    return _buildMediaFallback();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payload ?? const VRDetailPayload();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackgroundMedia(p),
          IgnorePointer(
            ignoring: !_showOverlay,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                setState(() => _showOverlay = !_showOverlay);
                if (_showOverlay) {
                  Future.delayed(const Duration(seconds: 3), () {
                    if (mounted) setState(() => _showOverlay = false);
                  });
                }
              },
              child: const SizedBox.expand(),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.4),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.6),
                ],
                stops: const [0.0, 0.15, 0.5, 1.0],
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 120,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionIcon(
                    Icons.visibility_outlined,
                    _formatCount(p.viewCount),
                  ),
                  const SizedBox(height: 20),
                  _buildActionIcon(
                    Icons.favorite_border,
                    _formatCount(p.likeCount),
                  ),
                  const SizedBox(height: 20),
                  _buildActionIcon(
                    Icons.chat_bubble_outline,
                    _formatCount(p.commentCount),
                  ),
                  const SizedBox(height: 20),
                  _buildActionIcon(
                    Icons.star_border,
                    _formatCount(p.saveCount),
                  ),
                  const SizedBox(height: 20),
                  _buildActionIcon(
                    Icons.reply,
                    _formatCount(p.shareCount),
                  ),
                  const SizedBox(height: 20),
                  _buildActionIcon(Icons.more_horiz, null),
                ],
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: 40,
            child: Icon(
              Icons.visibility_off_outlined,
              size: 28,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          Positioned(
            left: 0,
            right: 80,
            bottom: 20,
            child: SafeArea(child: _buildBottomOverlay(p)),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 64,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'VR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          if (_showInstruction && p.hasPlayableVideo)
            Center(child: _buildInstructionOverlay()),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(child: _buildAppBar(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Text(
            'VR',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, String? count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 28),
        if (count != null) ...[
          const SizedBox(height: 4),
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomOverlay(VRDetailPayload p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[900],
                  backgroundImage: p.avatarUrl.trim().isNotEmpty
                      ? NetworkImage(p.avatarUrl)
                      : null,
                  child: p.avatarUrl.trim().isEmpty
                      ? const Icon(Icons.person, color: Colors.white54)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            p.creatorName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      p.creatorHandle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (p.description.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              p.description,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () {},
              child: Text(
                'See More',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
