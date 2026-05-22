import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'profile_cached_posts_grid.dart';

/// Uploads and updates [profileGridThumbnailUrl] on a reel.
abstract final class ProfileGridThumbnailService {
  ProfileGridThumbnailService._();

  static Future<bool> updateThumbnailUrl({
    required String reelId,
    required String ownerUserId,
    required String url,
  }) async {
    final id = reelId.trim();
    final uid = ownerUserId.trim();
    if (id.isEmpty || uid.isEmpty) return false;

    final value = url.trim();
    try {
      await FirebaseFirestore.instance.collection('reels').doc(id).update({
        'profileGridThumbnailUrl': value,
      });
      ProfileCachedPostsGridState.patchPostInCache(
        uid: uid,
        reelId: id,
        profileGridThumbnailUrl: value,
      );
      return true;
    } catch (e, st) {
      debugPrint('ProfileGridThumbnailService.updateThumbnailUrl: $e\n$st');
      return false;
    }
  }

  static Future<bool> clearThumbnail({
    required String reelId,
    required String ownerUserId,
  }) {
    return updateThumbnailUrl(reelId: reelId, ownerUserId: ownerUserId, url: '');
  }

  static Future<String?> uploadFile({
    required String ownerUserId,
    required String reelId,
    required File file,
  }) async {
    final uid = ownerUserId.trim();
    final id = reelId.trim();
    if (uid.isEmpty || id.isEmpty) return null;

    final ext = _extFromPath(file.path);
    final ref = FirebaseStorage.instance.ref().child(
      'users/$uid/uploads/profile_grid_thumbnails/${id}_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    try {
      await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      return ref.getDownloadURL();
    } catch (e, st) {
      debugPrint('ProfileGridThumbnailService.uploadFile: $e\n$st');
      return null;
    }
  }

  /// Uploads [file] and saves URL on the reel. Returns the URL or null on failure.
  static Future<String?> setThumbnailFromFile({
    required String reelId,
    required String ownerUserId,
    required File file,
  }) async {
    final url = await uploadFile(
      ownerUserId: ownerUserId,
      reelId: reelId,
      file: file,
    );
    if (url == null || url.isEmpty) return null;
    final ok = await updateThumbnailUrl(
      reelId: reelId,
      ownerUserId: ownerUserId,
      url: url,
    );
    return ok ? url : null;
  }

  static String _extFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.heic')) return 'heic';
    if (lower.endsWith('.heif')) return 'heif';
    return 'jpg';
  }
}
