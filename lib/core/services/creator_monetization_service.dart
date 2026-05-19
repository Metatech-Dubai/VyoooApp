import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';

/// Client requests to enable/disable creator monetization (processed by Cloud Function).
class CreatorMonetizationService {
  CreatorMonetizationService._();
  static final CreatorMonetizationService _instance =
      CreatorMonetizationService._();
  factory CreatorMonetizationService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _requestsCollection = 'creator_monetization_requests';

  String get _currentUid => (AuthService().currentUser?.uid ?? '').trim();

  Future<void> setMonetizationEnabled({required bool enabled}) async {
    final userId = _currentUid;
    if (userId.isEmpty) {
      throw StateError('You must be signed in');
    }
    final reqRef = _firestore.collection(_requestsCollection).doc();
    await reqRef.set({
      'userId': userId,
      'enabled': enabled,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final result = await reqRef.snapshots().firstWhere(
      (snap) {
        final data = snap.data();
        if (data == null) return false;
        final status = (data['status'] as String? ?? '').trim().toLowerCase();
        return status == 'done' || status == 'error';
      },
    );

    final data = result.data();
    if (data == null) return;
    final status = (data['status'] as String? ?? '').trim().toLowerCase();
    if (status == 'error') {
      final message = (data['error'] as String? ?? '').trim();
      throw StateError(
        message.isNotEmpty ? message : 'Could not update monetization.',
      );
    }
  }
}
