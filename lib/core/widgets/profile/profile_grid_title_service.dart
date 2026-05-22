import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'profile_cached_posts_grid.dart';
import 'profile_grid_title.dart';

/// Updates [profileGridTitle] on a reel and refreshes profile grids.
abstract final class ProfileGridTitleService {
  ProfileGridTitleService._();

  static Future<bool> updateTitle({
    required String reelId,
    required String ownerUserId,
    required String title,
  }) async {
    final id = reelId.trim();
    final uid = ownerUserId.trim();
    if (id.isEmpty || uid.isEmpty) return false;

    final value = ProfileGridTitle.normalizeForSave(title);
    try {
      await FirebaseFirestore.instance.collection('reels').doc(id).update({
        'profileGridTitle': value,
      });
      ProfileCachedPostsGridState.patchPostInCache(
        uid: uid,
        reelId: id,
        profileGridTitle: value,
      );
      return true;
    } catch (e, st) {
      debugPrint('ProfileGridTitleService.updateTitle: $e\n$st');
      return false;
    }
  }
}
