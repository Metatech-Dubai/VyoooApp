import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
import 'user_service.dart';

/// Reels feed by tab. For You / Trending / VR use reels collection; Following uses users/{uid}/following.
/// Falls back to empty or mock when Firestore has no reels.
class ReelsService {
  ReelsService._();
  static final ReelsService _instance = ReelsService._();
  factory ReelsService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _reelsCollection = 'reels';

  /// Reels for "For You": orderBy createdAt desc.
  Future<List<Map<String, dynamic>>> getReelsForYou({int limit = 20}) async {
    try {
      final q = await _firestore
          .collection(_reelsCollection)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return q.docs.map((d) => _docToReelMap(d)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Reels from followed users only. Uses users/{uid}/following then reels where userId in that list.
  Future<List<Map<String, dynamic>>> getReelsFollowing({int limit = 20}) async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return [];
    try {
      final followingIds = await UserService().getFollowing(uid);
      if (followingIds.isEmpty) return [];
      final q = await _firestore
          .collection(_reelsCollection)
          .where('userId', whereIn: followingIds.take(10).toList())
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return q.docs.map((d) => _docToReelMap(d)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Trending: orderBy viewsCount desc.
  Future<List<Map<String, dynamic>>> getReelsTrending({int limit = 20}) async {
    try {
      final q = await _firestore
          .collection(_reelsCollection)
          .orderBy('viewsCount', descending: true)
          .limit(limit)
          .get();
      return q.docs.map((d) => _docToReelMap(d)).toList();
    } catch (_) {
      return [];
    }
  }

  /// VR tab: where isVR == true.
  Future<List<Map<String, dynamic>>> getReelsVR({int limit = 20}) async {
    try {
      final q = await _firestore
          .collection(_reelsCollection)
          .where('isVR', isEqualTo: true)
          .limit(limit)
          .get();
      return q.docs.map((d) => _docToReelMap(d)).toList();
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic> _docToReelMap(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    return {
      'id': d.id,
      'videoUrl': data['videoUrl'] ?? '',
      'username': data['username'] ?? '',
      'handle': data['handle'] ?? '',
      'caption': data['caption'] ?? '',
      'likes': (data['likes'] as num?)?.toInt() ?? 0,
      'comments': (data['comments'] as num?)?.toInt() ?? 0,
      'saves': (data['saves'] as num?)?.toInt() ?? 0,
      'views': (data['views'] as num?)?.toInt() ?? (data['viewsCount'] as num?)?.toInt() ?? 0,
      'shares': (data['shares'] as num?)?.toInt() ?? 0,
      'avatarUrl': data['profileImage'] ?? data['avatarUrl'] ?? '',
      'userId': data['userId'] ?? '',
    };
  }
}
