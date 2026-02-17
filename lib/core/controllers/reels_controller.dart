import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../services/auth_service.dart';

/// Controller for reel interactions. No UI logic here.
/// UI calls these methods for like, save, share, comment.
class ReelsController {
  ReelsController._();
  static final ReelsController _instance = ReelsController._();
  factory ReelsController() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? get _currentUserId => AuthService().currentUser?.uid;

  /// Like a reel. Toggles like state and updates Firestore.
  /// Optimistic UI: return new liked state immediately.
  Future<bool> likeReel({
    required String reelId,
    required bool currentlyLiked,
  }) async {
    final uid = _currentUserId;
    if (uid == null) return currentlyLiked;

    final newLikedState = !currentlyLiked;
    try {
      await _firestore.collection('reels').doc(reelId).update({
        'likes': newLikedState ? FieldValue.increment(1) : FieldValue.increment(-1),
      });
      await _firestore
          .collection('userLikes')
          .doc('${uid}_$reelId')
          .set({'userId': uid, 'reelId': reelId, 'likedAt': FieldValue.serverTimestamp()});
      if (!newLikedState) {
        await _firestore.collection('userLikes').doc('${uid}_$reelId').delete();
      }
    } catch (_) {
      // Optimistic UI: still return new state; background sync can retry
    }
    return newLikedState;
  }

  /// Save a reel. Toggles save state and updates Firestore.
  Future<bool> saveReel({
    required String reelId,
    required bool currentlySaved,
  }) async {
    final uid = _currentUserId;
    if (uid == null) return currentlySaved;

    final newSavedState = !currentlySaved;
    try {
      if (newSavedState) {
        await _firestore
            .collection('userSaves')
            .doc('${uid}_$reelId')
            .set({'userId': uid, 'reelId': reelId, 'savedAt': FieldValue.serverTimestamp()});
      } else {
        await _firestore.collection('userSaves').doc('${uid}_$reelId').delete();
      }
    } catch (_) {}
    return newSavedState;
  }

  /// Increment view count. Call when reel becomes visible.
  /// Do NOT increment on client directly; use Cloud Function or backend trigger.
  /// For now, writes to Firestore; in production use a Cloud Function.
  Future<void> incrementView({required String reelId}) async {
    final uid = _currentUserId;
    if (uid == null) return;
    try {
      await _firestore.collection('reels').doc(reelId).update({
        'views': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  /// Share a reel using native share sheet.
  Future<void> shareReel({
    required String reelId,
    String? reelUrl,
  }) async {
    try {
      final url = reelUrl ?? 'https://vyooo.com/reel/$reelId';
      await Share.share(url, subject: 'Check out this reel on Vyooo!');
    } on PlatformException catch (_) {
      // Share cancelled or unavailable
    } catch (_) {}
  }

  /// Open comment bottom sheet. Implementation in UI.
  /// This method is a placeholder; the actual UI calls the comment sheet.
  void openComments({required String reelId}) {
    // UI handles opening the comment bottom sheet
  }
}
