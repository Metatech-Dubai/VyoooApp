import 'package:flutter/material.dart';

import '../../core/controllers/reels_controller.dart';
import '../../core/services/reels_service.dart';
import '../../core/theme/app_padding.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_interaction_button.dart';
import '../../features/home/widgets/following_header_stories.dart';
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

  Future<void> _onShare(String reelId) async {
    await _reelsController.shareReel(reelId: reelId);
  }

  void _onComment(String reelId) {
    // TODO: Open comment bottom sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 400,
        decoration: const BoxDecoration(
          color: Color(0xFF1A0020),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const Center(
          child: Text(
            'Comments',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      ),
    );
  }

  void _onTabChanged(HomeTab tab) {
    setState(() {
      currentTab = tab;
      _currentIndex = 0;
    });
    _pageController.jumpToPage(0);
    if (tab == HomeTab.following) {
      // First reel auto-plays; story row already shown by build
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildReelsFeed(),
          _buildHeader(),
          if (currentTab == HomeTab.following) _buildStoryRow(),
          _buildInteractionButtons(),
          _buildBottomUserInfo(),
          if (_showControls) _buildControlsOverlay(),
        ],
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
        child: Padding(
          padding: AppPadding.screenHorizontal.copyWith(top: AppSpacing.md, bottom: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLogo(),
              Flexible(child: _buildTabMenu()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return SizedBox(
      height: 32,
      child: Image.asset(
        'assets/BrandLogo/Vyooo logo (2).png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Text(
          'VyooO',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTabMenu() {
    const tabs = [
      (HomeTab.trending, 'Trending'),
      (HomeTab.vr, 'VR'),
      (HomeTab.following, 'Following'),
      (HomeTab.forYou, 'For You'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: tabs.map((e) {
          final tab = e.$1;
          final label = e.$2;
          final isSelected = currentTab == tab;
          return GestureDetector(
            onTap: () => _onTabChanged(tab),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(left: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
              borderRadius: AppRadius.pillRadius,
            ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
          );
        }).toList(),
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
      bottom: 12, // just above nav bar (body ends at top of nav)
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppInteractionButton(
            icon: Icons.visibility,
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
            icon: Icons.comment,
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
            icon: Icons.share,
            count: _formatCount(reel['shares'] as int),
            onTap: () => _onShare(reelId),
          ),
        ],
      ),
    );
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
    return Center(
      child: AnimatedOpacity(
        opacity: _showControls ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: AppRadius.buttonRadius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _currentIndex < _currentReels.length && _isVideoPlaying()
                    ? Icons.pause
                    : Icons.play_arrow,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 16),
              const Icon(
                Icons.volume_up,
                color: Colors.white,
                size: 28,
              ),
            ],
          ),
        ),
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
