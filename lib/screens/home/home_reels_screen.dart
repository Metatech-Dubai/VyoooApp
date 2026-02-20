import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:provider/provider.dart';

import '../../core/controllers/reels_controller.dart';
import '../../core/services/reels_service.dart';
import '../../core/subscription/subscription_controller.dart';
import '../../core/theme/app_padding.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_feed_header.dart';
import '../../core/widgets/app_interaction_button.dart';
import '../../features/comments/widgets/comments_bottom_sheet.dart';
import '../../features/home/widgets/following_header_stories.dart';
import '../../features/reel/widgets/download_subscription_sheet.dart';
import '../../features/reel/widgets/manage_content_preferences_sheet.dart';
import '../../features/reel/widgets/not_interested_sheet.dart';
import '../../features/reel/widgets/playback_speed_sheet.dart';
import '../../features/reel/widgets/reel_more_options_sheet.dart';
import '../../features/reel/widgets/video_quality_sheet.dart';
import '../../features/reel/widgets/why_seeing_this_sheet.dart';
import '../../features/share/widgets/share_bottom_sheet.dart';
import '../../features/vr/vr_screen.dart';
import '../../widgets/reel_item_widget.dart';

enum HomeTab { trending, vr, following, forYou }

/// Main home screen: vertical reels feed with interactions.
/// Default tab: For You. Tab switch is internal state only (no new route).
class HomeReelsScreen extends StatefulWidget {
  const HomeReelsScreen({super.key});

  @override
  State<HomeReelsScreen> createState() => _HomeReelsScreenState();
}

class _HomeReelsScreenState extends State<HomeReelsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final PageController _pageController = PageController();
  final ReelsController _reelsController = ReelsController();
  final ReelsService _reelsService = ReelsService();

  int _currentIndex = 0;
  HomeTab currentTab = HomeTab.forYou;
  bool _showControls = false;
  List<Map<String, dynamic>> _reelsForYou = [];
  List<Map<String, dynamic>> _reelsFollowing = [];
  List<Map<String, dynamic>> _reelsTrending = [];
  List<Map<String, dynamic>> _reelsVR = [];
  String? _selectedStoryId;

  /// Reels for current tab. Rebuilt when currentTab changes; PageView uses this.
  List<Map<String, dynamic>> get _currentReels {
    switch (currentTab) {
      case HomeTab.trending:
        return _reelsTrending;
      case HomeTab.vr:
        return _reelsVR;
      case HomeTab.following:
        return _reelsFollowing;
      case HomeTab.forYou:
        return _reelsForYou;
    }
  }

  // Mock data - HQ car reels style. Used as fallback until Firestore has reels.
  static List<Map<String, dynamic>> get _mockReels => [
    {
      'id': 'reel1',
      'videoUrl': 'https://assets.mixkit.co/videos/24481/24481-720.mp4',
      'username': 'supercar_daily',
      'handle': '@supercardaily',
      'caption': 'Sunday drive hits different 🏎️ #carreels #luxury #vyooo',
      'likes': 28400,
      'comments': 892,
      'saves': 1203,
      'views': 412000,
      'shares': 456,
      'avatarUrl': '',
    },
    {
      'id': 'reel2',
      'videoUrl': 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
      'username': 'luxury_rides',
      'handle': '@luxuryrides',
      'caption': 'POV: you finally got the keys 🔑 #carlife #newcar #vyooo',
      'likes': 15600,
      'comments': 234,
      'saves': 567,
      'views': 198000,
      'shares': 189,
      'avatarUrl': '',
    },
    {
      'id': 'reel3',
      'videoUrl': 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      'username': 'street_garage',
      'handle': '@streetgarage',
      'caption': 'Build not bought 💪 #carmods #carreels #vyooo',
      'likes': 42100,
      'comments': 1204,
      'saves': 2100,
      'views': 890000,
      'shares': 678,
      'avatarUrl': '',
    },
    {
      'id': 'reel4',
      'videoUrl': 'https://assets.mixkit.co/videos/24481/24481-720.mp4',
      'username': 'night_drives',
      'handle': '@nightdrives',
      'caption': 'City lights & good vibes only 🌃 #nightdrive #carreels #vyooo',
      'likes': 33800,
      'comments': 567,
      'saves': 890,
      'views': 521000,
      'shares': 312,
      'avatarUrl': '',
    },
  ];

  // State for likes/saves (optimistic UI)
  final Map<String, bool> _likedReels = {};
  final Map<String, bool> _savedReels = {};

  // Playback and quality (from three-dots menu)
  String _playbackSpeedId = '1';
  String _playbackSpeedLabel = '1x (Normal)';
  String _qualityId = 'auto';
  String _qualityLabel = 'Auto (1080p HD)';

  @override
  void initState() {
    super.initState();
    _reelsForYou = _mockReels;
    _reelsFollowing = _mockReels;
    _reelsTrending = _mockReels;
    _reelsVR = _mockReels;
    _loadReels();
  }

  Future<void> _loadReels() async {
    final forYou = await _reelsService.getReelsForYou();
    final following = await _reelsService.getReelsFollowing();
    final trending = await _reelsService.getReelsTrending();
    final vr = await _reelsService.getReelsVR();
    if (mounted) {
      setState(() {
        if (forYou.isNotEmpty) _reelsForYou = forYou;
        if (following.isNotEmpty) _reelsFollowing = following;
        if (trending.isNotEmpty) _reelsTrending = trending;
        if (vr.isNotEmpty) _reelsVR = vr;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    if (index < _currentReels.length) {
      _reelsController.incrementView(reelId: _currentReels[index]['id'] as String);
    }
  }

  Future<void> _onLike(String reelId, bool currentlyLiked) async {
    final newState = await _reelsController.likeReel(
      reelId: reelId,
      currentlyLiked: currentlyLiked,
    );
    setState(() => _likedReels[reelId] = newState);
  }

  Future<void> _onSave(String reelId, bool currentlySaved) async {
    final newState = await _reelsController.saveReel(
      reelId: reelId,
      currentlySaved: currentlySaved,
    );
    setState(() => _savedReels[reelId] = newState);
  }

  void _onShare(String reelId) {
    final reel = _currentIndex < _currentReels.length ? _currentReels[_currentIndex] : null;
    showShareBottomSheet(
      context,
      reelId: reelId,
      authorName: reel?['username'] as String?,
      thumbnailUrl: reel?['thumbnailUrl'] as String?,
      onShareViaNative: () => _reelsController.shareReel(reelId: reelId),
      onCopyLink: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Link copied to clipboard'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  void _onComment(String reelId) {
    showCommentsBottomSheet(
      context,
      reelId: reelId,
      onReply: (_) => _showSnackBar('Reply'),
      onLike: (_) => _showSnackBar('Liked'),
      onViewReplies: (_) => _showSnackBar('View replies'),
    );
  }

  void _onTabChanged(HomeTab tab) {
    setState(() {
      currentTab = tab;
      _currentIndex = 0;
    });
    // PageView is only in the tree when tab != VR. Schedule jump after build.
    if (tab != HomeTab.vr) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && currentTab == tab && _pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      });
    }
  }

  void _onVideoTap() {
    setState(() => _showControls = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isVrTab = currentTab == HomeTab.vr;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (isVrTab) _buildVrContent() else _buildReelsFeed(),
          _buildHeader(),
          if (currentTab == HomeTab.following) _buildStoryRow(),
          if (!isVrTab) ...[
            _buildInteractionButtons(),
            _buildBottomUserInfo(),
            if (_showControls) _buildControlsOverlay(),
          ],
        ],
      ),
    );
  }

  Widget _buildVrContent() {
    return Positioned.fill(
      child: Consumer<SubscriptionController>(
        builder: (context, subscriptionController, _) {
          if (!subscriptionController.hasVRAccess) {
            return const VrLockedView();
          }
          return const VrGridView();
        },
      ),
    );
  }

  Widget _buildStoryRow() {
    final stories = _reelsFollowing
        .take(8)
        .map((r) => {
              'id': r['id'],
              'profileImage': r['avatarUrl'],
              'avatarUrl': r['avatarUrl'],
            })
        .toList();
    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: FollowingHeaderStories(
        stories: stories,
        selectedId: _selectedStoryId,
        onStoryTap: (id) => setState(() => _selectedStoryId = id),
      ),
    );
  }

  Widget _buildReelsFeed() {
    final reels = _currentReels;
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      onPageChanged: _onPageChanged,
      itemCount: reels.length,
      itemBuilder: (context, index) {
        final reel = reels[index];
        return GestureDetector(
          onTap: _onVideoTap,
          child: ReelItemWidget(
            videoUrl: reel['videoUrl'] as String,
            isVisible: index == _currentIndex,
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: AppFeedHeader(
          selectedIndex: currentTab.index,
          onTabSelected: (index) => _onTabChanged(HomeTab.values[index]),
        ),
      ),
    );
  }

  Widget _buildInteractionButtons() {
    if (_currentIndex >= _currentReels.length) return const SizedBox.shrink();
    final reel = _currentReels[_currentIndex];
    final reelId = reel['id'] as String;
    final isLiked = _likedReels[reelId] ?? false;
    final isSaved = _savedReels[reelId] ?? false;

    return Positioned(
      right: 16,
      bottom: 12,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppInteractionButton(
            icon: FontAwesomeIcons.crown,
            count: '',
            iconColor: const Color(0xFFFFD700),
          ),
          SizedBox(height: AppSpacing.lg),
          AppInteractionButton(
            icon: Icons.visibility_outlined,
            count: _formatCount(reel['views'] as int),
          ),
          SizedBox(height: AppSpacing.lg),
          AppInteractionButton(
            icon: isLiked ? Icons.favorite : Icons.favorite_border,
            count: _formatCount(reel['likes'] as int),
            isActive: isLiked,
            onTap: () => _onLike(reelId, isLiked),
          ),
          SizedBox(height: AppSpacing.lg),
          AppInteractionButton(
            icon: Icons.chat_bubble_outline,
            count: _formatCount(reel['comments'] as int),
            onTap: () => _onComment(reelId),
          ),
          SizedBox(height: AppSpacing.lg),
          AppInteractionButton(
            icon: isSaved ? Icons.star : Icons.star_border,
            count: _formatCount(reel['saves'] as int),
            isActive: isSaved,
            onTap: () => _onSave(reelId, isSaved),
          ),
          SizedBox(height: AppSpacing.lg),
          AppInteractionButton(
            icon: Icons.send_outlined,
            count: _formatCount(reel['shares'] as int),
            onTap: () => _onShare(reelId),
          ),
          SizedBox(height: AppSpacing.lg),
          AppInteractionButton(
            icon: Icons.more_horiz,
            count: '',
            onTap: () => _onMoreOptions(reelId),
          ),
        ],
      ),
    );
  }

  void _onMoreOptions(String reelId) {
    showReelMoreOptionsSheet(
      context,
      reelId: reelId,
      playbackSpeed: _playbackSpeedLabel,
      quality: _qualityLabel,
      onDownload: _onDownloadTapped,
      onReport: () => _showSnackBar('Report submitted'),
      onNotInterested: () => showNotInterestedSheet(context),
      onCaptions: () => _showSnackBar('Captions'),
      onPlaybackSpeed: _openPlaybackSpeedSheet,
      onQuality: _openVideoQualitySheet,
      onManagePreferences: () => showManageContentPreferencesSheet(context),
      onWhyThisPost: () => showWhySeeingThisSheet(context),
    );
  }

  void _onDownloadTapped() {
    final subscriptionController = context.read<SubscriptionController>();
    if (subscriptionController.isSubscriber || subscriptionController.isCreator) {
      _showSnackBar('Download started');
    } else {
      showDownloadSubscriptionSheet(context);
    }
  }

  void _openPlaybackSpeedSheet() {
    showPlaybackSpeedSheet(
      context,
      selectedId: _playbackSpeedId,
      onSelected: (id, label) {
        setState(() {
          _playbackSpeedId = id;
          _playbackSpeedLabel = label;
        });
        _showSnackBar('Playback speed: $label');
      },
    );
  }

  void _openVideoQualitySheet() {
    showVideoQualitySheet(
      context,
      selectedId: _qualityId,
      onSelected: (id, label) {
        setState(() {
          _qualityId = id;
          _qualityLabel = id == 'auto' ? 'Auto (1080p HD)' : label;
        });
        _showSnackBar('Quality: ${_qualityLabel}');
      },
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Widget _buildBottomUserInfo() {
    if (_currentIndex >= _currentReels.length) return const SizedBox.shrink();
    final reel = _currentReels[_currentIndex];

    return Positioned(
      left: 16,
      right: 80,
      bottom: 12, // just above nav bar (body ends at top of nav)
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage: (reel['avatarUrl'] as String).isNotEmpty
                    ? NetworkImage(reel['avatarUrl'] as String)
                    : null,
                child: (reel['avatarUrl'] as String).isEmpty
                    ? const Icon(Icons.person, color: Colors.white, size: 24)
                    : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reel['username'] as String,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    reel['handle'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            reel['caption'] as String,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'See More',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay() {
    final playing = _currentIndex < _currentReels.length && _isVideoPlaying();
    return Center(
      child: AnimatedOpacity(
        opacity: _showControls ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildControlCircle(
              icon: playing ? Icons.pause : Icons.play_arrow,
              onTap: _onVideoTap,
            ),
            const SizedBox(width: 20),
            _buildControlCircle(
              icon: Icons.volume_off_rounded,
              onTap: () {
                // TODO: Toggle mute; wire to player
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mute'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlCircle({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.25),
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }

  bool _isVideoPlaying() {
    // Placeholder - check actual player state from ReelItemWidget if needed
    return true;
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
