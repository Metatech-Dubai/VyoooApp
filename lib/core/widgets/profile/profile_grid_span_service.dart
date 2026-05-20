import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'profile_cached_posts_grid.dart';
import 'profile_grid_models.dart';
import 'profile_modular_grid.dart';

/// Updates [profileGridSpan] on a reel and refreshes profile grids.
abstract final class ProfileGridSpanService {
  ProfileGridSpanService._();

  static Future<bool> updateSpan({
    required String reelId,
    required String ownerUserId,
    required ProfileGridSpanOverride span,
  }) async {
    final id = reelId.trim();
    final uid = ownerUserId.trim();
    if (id.isEmpty || uid.isEmpty) return false;

    final value = profileGridSpanToFirestore(span);
    try {
      await FirebaseFirestore.instance.collection('reels').doc(id).update({
        'profileGridSpan': value,
      });
      ProfileCachedPostsGridState.patchPostInCache(
        uid: uid,
        reelId: id,
        profileGridSpan: value,
      );
      return true;
    } catch (e, st) {
      debugPrint('ProfileGridSpanService.updateSpan: $e\n$st');
      return false;
    }
  }
}
