import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user_model.dart';

/// Firestore user document operations. No UI, no BuildContext.
/// Call createUserDocument AFTER successful registration.
class UserService {
  UserService._();
  static final UserService _instance = UserService._();
  factory UserService() => _instance;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static const String _usersCollection = 'users';

  static Map<String, dynamic> _initialUserData(String uid, String email) => {
        'uid': uid,
        'email': email,
        'username': '',
        'dob': '',
        'profileImage': '',
        'interests': [],
        'onboardingCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

  /// Creates the initial user document. Call after AuthService.registerWithEmail success.
  Future<void> createUserDocument({
    required String uid,
    required String email,
  }) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).set(
            _initialUserData(uid, email),
          );
    } catch (e) {
      rethrow;
    }
  }

  /// Ensures the user document exists. Creates it only if missing (e.g. if createUserDocument failed at signup).
  Future<void> ensureUserDocument({
    required String uid,
    required String email,
  }) async {
    try {
      final docRef = _firestore.collection(_usersCollection).doc(uid);
      final doc = await docRef.get();
      if (!doc.exists) {
        await docRef.set(_initialUserData(uid, email));
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Updates user profile fields. Uses set with merge so the doc is created if it doesn't exist yet.
  Future<void> updateUserProfile({
    required String uid,
    String? username,
    String? dob,
    String? profileImage,
    List<String>? interests,
    bool? onboardingCompleted,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (username != null) data['username'] = username;
      if (dob != null) data['dob'] = dob;
      if (profileImage != null) data['profileImage'] = profileImage;
      if (interests != null) data['interests'] = interests;
      if (onboardingCompleted != null) data['onboardingCompleted'] = onboardingCompleted;
      if (data.isEmpty) return;
      await _firestore.collection(_usersCollection).doc(uid).set(
            data,
            SetOptions(merge: true),
          );
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches the user document. Returns null if not found or on error.
  Future<AppUserModel?> getUser(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return AppUserModel.fromJson(doc.data()!);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Stream of user document for reactive updates.
  Stream<AppUserModel?> userStream(String uid) {
    return _firestore
        .collection(_usersCollection)
        .doc(uid)
        .snapshots()
        .map((snap) {
      if (snap.exists && snap.data() != null) {
        return AppUserModel.fromJson(snap.data()!);
      }
      return null;
    });
  }

  /// List of user IDs the current user is following. Source: users/{uid}/following (array).
  Future<List<String>> getFollowing(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      final data = doc.data();
      if (data == null) return [];
      final following = data['following'];
      if (following is List) {
        return following.map((e) => e.toString()).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
