import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/controllers/reels_controller.dart';
import '../../../../core/mock/mock_feed_data.dart';
import '../../../../core/subscription/subscription_controller.dart';
import '../../../../core/widgets/app_bottom_navigation.dart';
import '../../../../core/widgets/app_feed_header.dart';
import '../../../../core/widgets/app_gradient_background.dart';
import '../../../comments/widgets/comments_bottom_sheet.dart';
import '../../../reel/widgets/download_subscription_sheet.dart';
import '../../../reel/widgets/manage_content_preferences_sheet.dart';
import '../../../reel/widgets/not_interested_sheet.dart';
import '../../../reel/widgets/playback_speed_sheet.dart';
import '../../../reel/widgets/reel_more_options_sheet.dart';
import '../../../reel/widgets/video_quality_sheet.dart';
import '../../../reel/widgets/why_seeing_this_sheet.dart';
import '../../../share/widgets/share_bottom_sheet.dart';
import '../widgets/feed_video_item.dart';
import '../widgets/story_avatar_list.dart';

/// Main feed screen (Following tab style): vertical video feed with header, stories, and bottom nav.
/// Clean architecture: UI only; no business logic. Ready for video controller later.
class FeedScreen extends StatefulWidget {
  const FeedScreen({
    super.key,
    this.showBottomNav = true,
    this.currentNavIndex = 0,
    this.onNavTap,
    this.profileImageUrl,
  });

  final bool showBottomNav;
  final int currentNavIndex;
  final void Function(int index)? onNavTap;
  final String? profileImageUrl;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final PageController _pageController = PageController();
  final Set<String> _likedPostIds = {};
  static const _items = mockFeedItems;
  static const _stories = mockStoryAvatars;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _openComments(BuildContext context, String postId) {
    showCommentsBottomSheet(
      context,
      reelId: postId,
      onReply: (_) => _showSnackBar(context, 'Reply'),
      onLike: (_) => _showSnackBar(context, 'Liked'),
      onViewReplies: (_) => _showSnackBar(context, 'View replies'),
    );
  }

  void _openShare(BuildContext context, String postId) {
    showShareBottomSheet(
      context,
      reelId: postId,
      onShareViaNative: () => ReelsController().shareReel(reelId: postId),
      onCopyLink: () => _showSnackBar(context, 'Link copied to clipboard'),
    );
  }

  void _openMoreOptions(BuildContext context, String postId) {
    final subscriptionController = context.read<SubscriptionController>();
    showReelMoreOptionsSheet(
      context,
      reelId: postId,
      playbackSpeed: '1x (Normal)',
      quality: 'Auto (1080p HD)',
      onDownload: () {
        if (subscriptionController.isSubscriber || subscriptionController.isCreator) {
          _showSnackBar(context, 'Download started');
        } else {
          showDownloadSubscriptionSheet(context);
        }
      },
      onReport: () => _showSnackBar(context, 'Report submitted'),
      onNotInterested: () => showNotInterestedSheet(context),
      onCaptions: () => _showSnackBar(context, 'Captions'),
      onPlaybackSpeed: () => showPlaybackSpeedSheet(
        context,
        selectedId: '1',
        onSelected: (_, label) => _showSnackBar(context, 'Playback speed: $label'),
      ),
      onQuality: () => showVideoQualitySheet(
        context,
        selectedId: 'auto',
        onSelected: (_, label) => _showSnackBar(context, 'Quality: $label'),
      ),
      onManagePreferences: () => showManageContentPreferencesSheet(context),
      onWhyThisPost: () => showWhySeeingThisSheet(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AppGradientBackground(
        type: GradientType.feed,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppFeedHeader(
              selectedIndex: 2,
              onTabSelected: (_) {},
            ),
            StoryAvatarList(
              avatars: _stories,
              onAvatarTap: (_) {},
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final post = _items[index];
                  final isLiked = _likedPostIds.contains(post.id);
                  return FeedVideoItem(
                    post: post,
                    isLiked: isLiked,
                    onLike: () {
                      setState(() {
                        if (isLiked) {
                          _likedPostIds.remove(post.id);
                        } else {
                          _likedPostIds.add(post.id);
                        }
                      });
                    },
                    onComment: () => _openComments(context, post.id),
                    onShare: () => _openShare(context, post.id),
                    onMore: () => _openMoreOptions(context, post.id),
                    onSeeMore: () => _showSnackBar(context, 'See more'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.showBottomNav
          ? AppBottomNavigation(
              currentIndex: widget.currentNavIndex,
              onTap: widget.onNavTap ?? (_) {},
              profileImageUrl: widget.profileImageUrl,
            )
          : null,
    );
  }
}
