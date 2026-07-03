import 'package:flutter/material.dart';

import '../../core/models/reel_media_item.dart';
import '../../core/models/video_360_metadata.dart';
import '../../core/services/vr_video_cache_service.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/video_upload_policy.dart';
import '../../core/widgets/post_media_carousel.dart';
import '../../widgets/reel_item_widget.dart';

/// Vertical VR reel feed — same swipe-to-browse experience as the home VR tab.
class VrReelsFeedView extends StatefulWidget {
  const VrReelsFeedView({
    super.key,
    required this.reels,
    this.isLoading = false,
    this.emptyTitle = 'No VR videos yet',
    this.emptySubtitle =
        'Immersive 360° content will appear here when creators publish it.',
    this.onRefresh,
  });

  final List<Map<String, dynamic>> reels;
  final bool isLoading;
  final String emptyTitle;
  final String emptySubtitle;
  final Future<void> Function()? onRefresh;

  @override
  State<VrReelsFeedView> createState() => _VrReelsFeedViewState();
}

class _VrReelsFeedViewState extends State<VrReelsFeedView> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _warmCache();
  }

  @override
  void didUpdateWidget(covariant VrReelsFeedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reels != widget.reels) {
      _warmCache();
      if (_currentIndex >= widget.reels.length) {
        _currentIndex = 0;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients && widget.reels.isNotEmpty) {
            _pageController.jumpToPage(0);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _warmCache() {
    if (widget.reels.isEmpty) return;
    final head = widget.reels.take(5).toList(growable: false);
    VrVideoCacheService.instance.syncForFeed(head);
    _prefetchAround(_currentIndex);
  }

  void _prefetchAround(int index) {
    final reels = widget.reels;
    if (reels.isEmpty) return;
    for (final offset in const [0, 1]) {
      final i = (index + offset) % reels.length;
      final url = ((reels[i]['videoUrl'] as String?) ?? '').trim();
      if (url.isNotEmpty) VrVideoCacheService.instance.prefetch(url);
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _prefetchAround(index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading && widget.reels.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFDE106B)),
      );
    }

    if (widget.reels.isEmpty) {
      return _EmptyState(
        title: widget.emptyTitle,
        subtitle: widget.emptySubtitle,
        onRefresh: widget.onRefresh,
      );
    }

    final body = ClipRRect(
      borderRadius: AppRadius.feedPostBottomRadius,
      clipBehavior: Clip.antiAlias,
      child: ColoredBox(
        color: Colors.black,
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          onPageChanged: _onPageChanged,
          itemCount: widget.reels.length,
          itemBuilder: (context, index) {
            return _VrReelPage(
              reel: widget.reels[index],
              isVisible: index == _currentIndex,
            );
          },
        ),
      ),
    );

    if (widget.onRefresh == null) return body;

    return RefreshIndicator(
      color: const Color(0xFFDE106B),
      onRefresh: widget.onRefresh!,
      child: body,
    );
  }
}

class _VrReelPage extends StatelessWidget {
  const _VrReelPage({required this.reel, required this.isVisible});

  final Map<String, dynamic> reel;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    final mediaItems = ReelMediaItem.listFromPost(reel);
    final video360 = Video360Metadata.forVrPlayback(reel);

    if (mediaItems.length > 1) {
      return PostMediaCarousel(
        items: mediaItems,
        video360: video360,
        imageFit: BoxFit.cover,
        isVisible: isVisible,
      );
    }

    final mediaType = ((reel['mediaType'] as String?) ?? 'video').toLowerCase();
    if (mediaType == 'image') {
      final imageUrl = ((reel['imageUrl'] as String?) ?? '').trim();
      final thumb = ((reel['thumbnailUrl'] as String?) ?? '').trim();
      final display = imageUrl.isNotEmpty ? imageUrl : thumb;
      if (display.isEmpty) {
        return const _MissingMediaPlaceholder();
      }
      return Image.network(
        display,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => const _MissingMediaPlaceholder(),
      );
    }

    final videoUrl = ((reel['videoUrl'] as String?) ?? '').trim();
    if (!VideoUploadPolicy.isPlayableUrl(videoUrl)) {
      return const _MissingMediaPlaceholder();
    }

    final thumb = ((reel['thumbnailUrl'] as String?) ?? '').trim();
    final imageUrl = ((reel['imageUrl'] as String?) ?? '').trim();
    final loadingThumb = thumb.isNotEmpty ? thumb : imageUrl;

    return ReelItemWidget(
      key: ValueKey<String>((reel['id'] as String?) ?? videoUrl),
      videoUrl: videoUrl,
      thumbnailUrl: loadingThumb,
      video360: video360,
      isVisible: isVisible,
      showEmbeddedProgressBar: true,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
    this.onRefresh,
  });

  final String title;
  final String subtitle;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.vrpano_outlined,
              size: 48,
              color: Colors.white.withValues(alpha: 0.35),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 14,
                height: 1.35,
              ),
            ),
            if (onRefresh != null) ...[
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: () => onRefresh!(),
                child: const Text(
                  'Refresh',
                  style: TextStyle(
                    color: Color(0xFFDE106B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MissingMediaPlaceholder extends StatelessWidget {
  const _MissingMediaPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Icon(
          Icons.videocam_off_outlined,
          size: 48,
          color: Colors.white.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
