import 'package:flutter/foundation.dart';

/// After [CreateUsernameScreen] confirms a username on the server, Firestore
/// `snapshots()` can briefly emit a stale doc (empty username). This stores the
/// saved username + account type so [AuthWrapper] can advance onboarding until
/// the user stream matches.
class UsernameSubmitHandoff extends ChangeNotifier {
  UsernameSubmitHandoff._();
  static final UsernameSubmitHandoff instance = UsernameSubmitHandoff._();

  String? _uid;
  String? _username;
  String? _accountType;
  DateTime? _expiresAt;

  bool isActiveFor(String uid) {
    if (_uid != uid || _username == null || _expiresAt == null) {
      return false;
    }
    if (DateTime.now().isAfter(_expiresAt!)) {
      disarm(uid: uid);
      return false;
    }
    return true;
  }

  String? savedUsernameFor(String uid) {
    if (!isActiveFor(uid)) return null;
    return _username;
  }

  String? savedAccountTypeFor(String uid) {
    if (!isActiveFor(uid)) return null;
    return _accountType;
  }

  void arm({
    required String uid,
    required String username,
    required String accountType,
    Duration ttl = const Duration(minutes: 5),
  }) {
    _uid = uid;
    _username = username;
    _accountType = accountType;
    _expiresAt = DateTime.now().add(ttl);
    notifyListeners();
  }

  /// Clears handoff for [uid], or everything if [uid] is null.
  void disarm({String? uid}) {
    final had = _username != null;
    if (uid != null && _uid != uid) return;
    _uid = null;
    _username = null;
    _accountType = null;
    _expiresAt = null;
    if (had) notifyListeners();
  }
}
