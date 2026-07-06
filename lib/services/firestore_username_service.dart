import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'reserved_usernames.dart';
import 'username_service.dart';
import 'username_validation.dart';

/// Live username availability using `users` + `username` field (case-sensitive).
class FirestoreUsernameService implements UsernameService {
  static List<String> _suggestionsFor(String base) {
    if (base.isEmpty) return [];
    return [
      '${base}_official',
      '${base}123',
      'the_$base',
      '${base}_app',
    ];
  }

  static UsernameCheckResult _reservedResult(String normalized) {
    return UsernameCheckResult(
      available: false,
      isReserved: true,
      suggestions: const [],
    );
  }

  static bool _takenByOther(
    QuerySnapshot<Map<String, dynamic>> snap,
    String excludeUid,
  ) {
    for (final d in snap.docs) {
      final data = d.data();
      final docUid = (data['uid'] as String?)?.trim() ?? d.id;
      if (docUid != excludeUid) return true;
    }
    return false;
  }

  static Future<bool> _isReserved(String normalized) async {
    final key = normalized.toLowerCase();
    try {
      final snap = await FirebaseFirestore.instance
          .collection('reserved_usernames')
          .doc(key)
          .get();
      if (snap.exists) {
        final active = snap.data()?['active'];
        if (active is bool) return active;
        return true;
      }
    } catch (_) {
      // Fall back to bundled policy when Firestore is unreachable.
    }
    return ReservedUsernames.isReserved(normalized);
  }

  @override
  Future<UsernameCheckResult> checkAvailability(String username) async {
    final normalized = UsernameValidation.normalize(username);
    if (!UsernameValidation.shouldCheckAvailability(normalized)) {
      return const UsernameCheckResult(available: true);
    }
    if (await _isReserved(normalized)) {
      return _reservedResult(normalized);
    }
    final excludeUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: normalized)
        .limit(25)
        .get();
    final taken = _takenByOther(snap, excludeUid);
    return UsernameCheckResult(
      available: !taken,
      suggestions: taken ? _suggestionsFor(normalized) : const [],
    );
  }

  @override
  Stream<UsernameCheckResult> watchAvailability(
    String username, {
    required String excludeUid,
  }) {
    final normalized = UsernameValidation.normalize(username);
    if (!UsernameValidation.shouldCheckAvailability(normalized)) {
      return Stream.value(const UsernameCheckResult(available: true));
    }

    return Stream.fromFuture(_isReserved(normalized)).asyncExpand((reserved) {
      if (reserved) {
        return Stream.value(_reservedResult(normalized));
      }
      return FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: normalized)
          .limit(25)
          .snapshots()
          .map((snap) {
            final taken = _takenByOther(snap, excludeUid);
            return UsernameCheckResult(
              available: !taken,
              suggestions: taken ? _suggestionsFor(normalized) : const [],
            );
          });
    });
  }
}
