import 'package:flutter/foundation.dart';

import '../widgets/profile/profile_cached_posts_grid.dart';

/// Signals [MainNavWrapper] to return home, open For You, and show an upload toast.
class PostUploadResult {
  const PostUploadResult({
    required this.reelId,
    required this.message,
    required this.userId,
  });

  final String reelId;
  final String message;
  final String userId;
}

abstract final class PostUploadNavigation {
  static final ValueNotifier<PostUploadResult?> pending = ValueNotifier(null);

  /// Bumped after upload so [ProfileScreen] can drop in-memory tab caches.
  static final ValueNotifier<int> profileRefreshToken = ValueNotifier(0);

  static bool _suppressNextCreateMenuRefresh = false;

  static void complete({
    required String reelId,
    required List<Map<String, dynamic>> mediaItems,
    required String userId,
  }) {
    _suppressNextCreateMenuRefresh = true;
    final uid = userId.trim();
    if (uid.isNotEmpty) {
      ProfileCachedPostsGrid.invalidateCacheFor(uid);
      profileRefreshToken.value++;
    }
    pending.value = PostUploadResult(
      reelId: reelId,
      message: uploadSuccessMessage(mediaItems),
      userId: uid,
    );
  }

  /// Skips the generic home refresh [MainNavWrapper] runs when the upload stack pops.
  static bool consumeCreateMenuRefreshSuppression() {
    if (!_suppressNextCreateMenuRefresh) return false;
    _suppressNextCreateMenuRefresh = false;
    return true;
  }

  static String uploadSuccessMessage(List<Map<String, dynamic>> mediaItems) {
    final hasVideo = mediaItems.any((e) => e['type'] == 'video');
    final hasImage = mediaItems.any((e) => e['type'] == 'image');
    final count = mediaItems.length;

    if (hasVideo && !hasImage) {
      return count > 1 ? 'Your reels are uploaded' : 'Your reel is uploaded';
    }
    if (hasImage && !hasVideo) {
      return count > 1 ? 'Your posts are uploaded' : 'Your post is uploaded';
    }
    return count > 1 ? 'Your posts are uploaded' : 'Your post is uploaded';
  }
}
