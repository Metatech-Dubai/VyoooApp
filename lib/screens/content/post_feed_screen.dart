import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_bottom_navigation.dart';
import '../../core/widgets/app_gradient_background.dart';

/// Payload for opening the post feed (e.g. from profile post grid).
class PostFeedPayload {
  const PostFeedPayload({
    this.initialIndex = 0,
    this.creatorName = 'Matt Rife',
    this.creatorHandle = '@mattrife_x',
    this.avatarUrl = 'https://i.pravatar.cc/80?img=33',
    this.isVerified = true,
  });

  final int initialIndex;
  final String creatorName;
  final String creatorHandle;
  final String avatarUrl;
  final bool isVerified;
}

/// Full-screen posts feed: app bar "Posts", scrollable post cards (avatar, caption, media, like/comment/share/save).
/// Design-only; matches Posts view from spec.
class PostFeedScreen extends StatefulWidget {
  const PostFeedScreen({super.key, this.payload});

  final PostFeedPayload? payload;

  @override
  State<PostFeedScreen> createState() => _PostFeedScreenState();
}

class _PostFeedScreenState extends State<PostFeedScreen> {
  static const List<_MockPost> _posts = [
    _MockPost(
      caption: 'This place is my home! Thank you again for having me! 🙌',
      mediaUrl: 'https://picsum.photos/800/900?random=pf1',
      likeCount: 3100,
      commentCount: 165,
      timestamp: '1 day ago',
      isCarousel: true,
      currentPage: 0,
    ),
    _MockPost(
      caption: 'A sunset between mountains casts a warm, golden glow over the peaks, creating a serene and peaceful atmosphere that reminds us of nature\'s beauty...',
      captionReadMore: true,
      mediaUrl: 'https://picsum.photos/800/900?random=pf2',
      likeCount: 892,
      commentCount: 42,
      timestamp: '2 days ago',
      isCarousel: false,
    ),
    _MockPost(
      caption: 'Another moment worth sharing.',
      mediaUrl: 'https://picsum.photos/800/900?random=pf3',
      likeCount: 1200,
      commentCount: 88,
      timestamp: '3 days ago',
      isCarousel: false,
    ),
  ];

  int _currentBottomNavIndex = 4;

  @override
  Widget build(BuildContext context) {
    final p = widget.payload ?? const PostFeedPayload();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType.feed,
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                itemCount: _posts.length,
                itemBuilder: (context, index) => _PostCard(
                  post: _posts[index],
                  creatorName: p.creatorName,
                  creatorHandle: p.creatorHandle,
                  avatarUrl: p.avatarUrl,
                  isVerified: p.isVerified,
                ),
              ),
            ),
            AppBottomNavigation(
              currentIndex: _currentBottomNavIndex,
              onTap: (index) {
                if (index == 4) return;
                setState(() => _currentBottomNavIndex = index);
                _navigateFromBottomNav(context, index);
              },
              profileImageUrl: p.avatarUrl,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Text(
            'Posts',
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

  void _navigateFromBottomNav(BuildContext context, int index) {
    // Keep user on this screen for design; in real app would switch tab.
  }
}

class _MockPost {
  const _MockPost({
    required this.caption,
    required this.mediaUrl,
    required this.likeCount,
    required this.commentCount,
    required this.timestamp,
    required this.isCarousel,
    this.captionReadMore = false,
    this.currentPage = 0,
  });
  final String caption;
  final String mediaUrl;
  final int likeCount;
  final int commentCount;
  final String timestamp;
  final bool isCarousel;
  final bool captionReadMore;
  final int currentPage;
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.creatorName,
    required this.creatorHandle,
    required this.avatarUrl,
    required this.isVerified,
  });

  final _MockPost post;
  final String creatorName;
  final String creatorHandle;
  final String avatarUrl;
  final bool isVerified;

  static String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage: NetworkImage(avatarUrl),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      creatorName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.check_circle_rounded, size: 16, color: AppColors.deleteRed),
                    ],
                  ],
                ),
              ),
              Text(
                post.timestamp,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
              ),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.more_horiz_rounded, color: Colors.white.withValues(alpha: 0.8), size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            post.caption,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
            maxLines: post.captionReadMore ? 3 : 10,
            overflow: TextOverflow.ellipsis,
          ),
          if (post.captionReadMore)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: GestureDetector(
                onTap: () {},
                child: const Text(
                  'Read more',
                  style: TextStyle(
                    color: Color(0xFFDE106B),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.input),
            child: AspectRatio(
              aspectRatio: 800 / 900,
              child: Image.network(post.mediaUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.favorite_rounded, color: Colors.white.withValues(alpha: 0.9), size: 22),
              const SizedBox(width: 4),
              Text(
                _formatCount(post.likeCount),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
              ),
              const SizedBox(width: AppSpacing.lg),
              Icon(Icons.chat_bubble_outline_rounded, color: Colors.white.withValues(alpha: 0.9), size: 22),
              const SizedBox(width: 4),
              Text(
                '${post.commentCount}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
              ),
              const SizedBox(width: AppSpacing.lg),
              Icon(Icons.share_rounded, color: Colors.white.withValues(alpha: 0.9), size: 22),
              const Spacer(),
              Icon(Icons.star_outline_rounded, color: Colors.white.withValues(alpha: 0.9), size: 22),
              if (post.isCarousel) ...[
                const SizedBox(width: AppSpacing.sm),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) => Container(
                    margin: const EdgeInsets.only(right: 4),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == post.currentPage
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                    ),
                  )),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
