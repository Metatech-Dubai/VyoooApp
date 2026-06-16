/// How the user originally signed in — used to restore the session when switching.
enum SavedAccountLoginType {
  password,
  google,
  apple;

  String get storageValue => name;

  static SavedAccountLoginType fromStorage(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'google':
        return SavedAccountLoginType.google;
      case 'apple':
        return SavedAccountLoginType.apple;
      default:
        return SavedAccountLoginType.password;
    }
  }
}

/// A Vyooo account saved on this device for quick switching (Instagram-style).
class SavedAccount {
  const SavedAccount({
    required this.uid,
    required this.username,
    required this.displayName,
    this.profileImageUrl,
    required this.loginType,
    required this.hasStoredCredentials,
    required this.lastUsedAtMs,
  });

  final String uid;
  final String username;
  final String displayName;
  final String? profileImageUrl;
  final SavedAccountLoginType loginType;
  final bool hasStoredCredentials;
  final int lastUsedAtMs;

  String get label {
    final user = username.trim();
    if (user.isNotEmpty) return '@$user';
    final name = displayName.trim();
    if (name.isNotEmpty) return name;
    return 'Account';
  }

  SavedAccount copyWith({
    String? uid,
    String? username,
    String? displayName,
    String? profileImageUrl,
    SavedAccountLoginType? loginType,
    bool? hasStoredCredentials,
    int? lastUsedAtMs,
  }) {
    return SavedAccount(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      loginType: loginType ?? this.loginType,
      hasStoredCredentials:
          hasStoredCredentials ?? this.hasStoredCredentials,
      lastUsedAtMs: lastUsedAtMs ?? this.lastUsedAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'username': username,
        'displayName': displayName,
        'profileImageUrl': profileImageUrl ?? '',
        'loginType': loginType.storageValue,
        'hasStoredCredentials': hasStoredCredentials,
        'lastUsedAtMs': lastUsedAtMs,
      };

  factory SavedAccount.fromJson(Map<String, dynamic> json) {
    return SavedAccount(
      uid: (json['uid'] as String? ?? '').trim(),
      username: (json['username'] as String? ?? '').trim(),
      displayName: (json['displayName'] as String? ?? '').trim(),
      profileImageUrl: _nullableString(json['profileImageUrl']),
      loginType: SavedAccountLoginType.fromStorage(
        json['loginType'] as String?,
      ),
      hasStoredCredentials: json['hasStoredCredentials'] == true,
      lastUsedAtMs: _readInt(json['lastUsedAtMs']),
    );
  }

  static String? _nullableString(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }
}

class SavedAccountPasswordCredentials {
  const SavedAccountPasswordCredentials({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;
}
