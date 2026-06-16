import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user_model.dart';
import '../models/saved_account.dart';
import 'user_service.dart';

/// Persists multiple logged-in accounts on device for Instagram-style switching.
///
/// Firebase Auth only holds one active session; we store per-account credentials
/// in secure storage and re-authenticate when the user picks another account.
class SavedAccountsService {
  SavedAccountsService._();
  static final SavedAccountsService _instance = SavedAccountsService._();
  factory SavedAccountsService() => _instance;

  static const int maxAccounts = 5;
  static const String _prefsKey = 'saved_accounts_v1';
  static const String _credKeyPrefix = 'vyooo_saved_account_cred_';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Bumps when the saved account list changes so UI can refresh.
  static final ValueNotifier<int> revision = ValueNotifier(0);

  static void _bumpRevision() {
    revision.value = revision.value + 1;
  }

  Future<List<SavedAccount>> getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) return <SavedAccount>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <SavedAccount>[];
      final accounts = decoded
          .whereType<Map>()
          .map((e) => SavedAccount.fromJson(Map<String, dynamic>.from(e)))
          .where((a) => a.uid.isNotEmpty)
          .toList();
      accounts.sort((a, b) => b.lastUsedAtMs.compareTo(a.lastUsedAtMs));
      return accounts;
    } catch (_) {
      return <SavedAccount>[];
    }
  }

  Future<List<SavedAccount>> _mutableAccounts() async {
    return List<SavedAccount>.from(await getAccounts());
  }

  Future<SavedAccount?> getAccount(String uid) async {
    final normalized = uid.trim();
    if (normalized.isEmpty) return null;
    final accounts = await getAccounts();
    for (final account in accounts) {
      if (account.uid == normalized) return account;
    }
    return null;
  }

  Future<SavedAccount?> getMostRecentlyUsedAccount({String? excludingUid}) async {
    final accounts = await getAccounts();
    final exclude = excludingUid?.trim() ?? '';
    for (final account in accounts) {
      if (exclude.isNotEmpty && account.uid == exclude) continue;
      return account;
    }
    return null;
  }

  Future<void> _persistAccounts(List<SavedAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = accounts.map((a) => a.toJson()).toList();
    await prefs.setString(_prefsKey, jsonEncode(payload));
    _bumpRevision();
  }

  Future<void> registerAccount({
    required User user,
    required SavedAccountLoginType loginType,
    AppUserModel? profile,
    String? email,
    String? password,
    bool markAsActive = true,
  }) async {
    final uid = user.uid.trim();
    if (uid.isEmpty) return;

    profile ??= await UserService().getUser(uid);
    final now = DateTime.now().millisecondsSinceEpoch;
    final accounts = await _mutableAccounts();
    final existingIndex = accounts.indexWhere((a) => a.uid == uid);
    final existing = existingIndex >= 0 ? accounts[existingIndex] : null;

    var hasCredentials = existing?.hasStoredCredentials ?? false;
    if (loginType == SavedAccountLoginType.password &&
        email != null &&
        email.trim().isNotEmpty &&
        password != null &&
        password.isNotEmpty) {
      await _storePasswordCredentials(
        uid: uid,
        email: email.trim(),
        password: password,
      );
      hasCredentials = true;
    } else if (loginType == SavedAccountLoginType.google ||
        loginType == SavedAccountLoginType.apple) {
      hasCredentials = true;
    }

    final username = (profile?.username ?? '').trim();
    final displayName = (profile?.displayName ?? user.displayName ?? '').trim();
    final avatar = (profile?.profileImage ?? user.photoURL ?? '').trim();

    final updated = SavedAccount(
      uid: uid,
      username: username,
      displayName: displayName,
      profileImageUrl: avatar.isEmpty ? null : avatar,
      loginType: loginType,
      hasStoredCredentials: hasCredentials,
      lastUsedAtMs: markAsActive ? now : (existing?.lastUsedAtMs ?? now),
    );

    if (existingIndex >= 0) {
      accounts[existingIndex] = updated;
    } else {
      if (accounts.length >= maxAccounts) {
        final removable = List<SavedAccount>.from(accounts)
          ..sort((a, b) => a.lastUsedAtMs.compareTo(b.lastUsedAtMs));
        final toRemove = removable.firstWhere(
          (a) => a.uid != uid,
          orElse: () => removable.first,
        );
        accounts.removeWhere((a) => a.uid == toRemove.uid);
        await _secureStorage.delete(key: '$_credKeyPrefix${toRemove.uid}');
      }
      accounts.add(updated);
    }

    await _persistAccounts(accounts);
  }

  Future<void> syncCurrentAccountMetadata() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    final existing = await getAccount(user.uid);
    await registerAccount(
      user: user,
      loginType: existing?.loginType ?? _loginTypeForUser(user),
      markAsActive: true,
    );
  }

  SavedAccountLoginType _loginTypeForUser(User user) {
    final providers = user.providerData.map((p) => p.providerId).toSet();
    if (providers.contains('google.com')) {
      return SavedAccountLoginType.google;
    }
    if (providers.contains('apple.com')) {
      return SavedAccountLoginType.apple;
    }
    return SavedAccountLoginType.password;
  }

  Future<void> markLastUsed(String uid) async {
    final normalized = uid.trim();
    if (normalized.isEmpty) return;
    final accounts = await _mutableAccounts();
    final index = accounts.indexWhere((a) => a.uid == normalized);
    if (index < 0) return;
    accounts[index] = accounts[index].copyWith(
      lastUsedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _persistAccounts(accounts);
  }

  Future<void> refreshAccountMetadata(String uid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != uid) return;
    final existing = await getAccount(uid);
    if (existing == null) return;
    final profile = await UserService().getUser(uid);
    await registerAccount(
      user: user,
      loginType: existing.loginType,
      profile: profile,
      markAsActive: true,
    );
  }

  Future<void> removeAccount(String uid) async {
    final normalized = uid.trim();
    if (normalized.isEmpty) return;
    final accounts = await _mutableAccounts()
      ..removeWhere((a) => a.uid == normalized);
    await _persistAccounts(accounts);
    await _secureStorage.delete(key: '$_credKeyPrefix$normalized');
  }

  Future<SavedAccountPasswordCredentials?> getPasswordCredentials(
    String uid,
  ) async {
    final raw = await _secureStorage.read(key: '$_credKeyPrefix${uid.trim()}');
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final email = (decoded['email'] as String? ?? '').trim();
      final password = decoded['password'] as String? ?? '';
      if (email.isEmpty || password.isEmpty) return null;
      return SavedAccountPasswordCredentials(email: email, password: password);
    } catch (_) {
      return null;
    }
  }

  Future<void> _storePasswordCredentials({
    required String uid,
    required String email,
    required String password,
  }) async {
    final payload = jsonEncode({'email': email, 'password': password});
    await _secureStorage.write(key: '$_credKeyPrefix$uid', value: payload);
  }

  Future<void> prepareForAddAccount() async {
    await syncCurrentAccountMetadata();
  }
}
