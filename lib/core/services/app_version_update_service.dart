import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_version_policy.dart';
import '../utils/app_version_compare.dart';

enum AppUpdateRequirement { none, optional, required }

/// Evaluates Firestore [AppVersionPolicy] against the installed app version.
class AppVersionUpdateService {
  AppVersionUpdateService._();
  static final AppVersionUpdateService instance = AppVersionUpdateService._();

  static const _cacheKey = 'app_version_policy_cache_v1';
  static const _optionalDismissVersionKey =
      'app_version_optional_dismissed_for_v1';
  static const _optionalDismissAtKey = 'app_version_optional_dismissed_at_v1';
  static const Duration _fetchTimeout = Duration(seconds: 8);
  static const Duration _optionalReshowAfter = Duration(hours: 24);

  static const bypassCheck = kDebugMode &&
      bool.fromEnvironment('BYPASS_VERSION_CHECK', defaultValue: false);

  PackageInfo? _packageInfo;

  Future<PackageInfo> _loadPackageInfo() async {
    _packageInfo ??= await PackageInfo.fromPlatform();
    return _packageInfo!;
  }

  Future<AppVersionPolicy> fetchPolicy({bool preferCacheOnFailure = true}) async {
    if (bypassCheck) return AppVersionPolicy.disabled();

    try {
      final snap = await FirebaseFirestore.instance
          .collection(AppVersionPolicy.firestoreCollection)
          .doc(AppVersionPolicy.firestoreDocumentId)
          .get()
          .timeout(_fetchTimeout);
      final policy = AppVersionPolicy.fromMap(snap.data());
      await _cachePolicy(policy);
      return policy;
    } catch (e, st) {
      developer.log(
        'version_policy fetch failed',
        name: 'vyooo.version',
        error: e,
        stackTrace: st,
      );
      if (preferCacheOnFailure) {
        final cached = await _readCachedPolicy();
        if (cached != null) return cached;
      }
      return AppVersionPolicy.disabled();
    }
  }

  Future<AppUpdateCheckResult> evaluate({AppVersionPolicy? policy}) async {
    if (bypassCheck) {
      return const AppUpdateCheckResult(requirement: AppUpdateRequirement.none);
    }

    final resolvedPolicy = policy ?? await fetchPolicy();
    final info = await _loadPackageInfo();
    final installedVersion = info.version.trim();
    final installedBuild = int.tryParse(info.buildNumber.trim()) ?? 0;
    final platform = resolvedPolicy.platformPolicy();

    if (!resolvedPolicy.enabled) {
      return AppUpdateCheckResult(
        requirement: AppUpdateRequirement.none,
        installedVersion: installedVersion,
        installedBuildNumber: installedBuild,
        policy: resolvedPolicy,
      );
    }

    final updateUrl = platform.updateUrl?.trim();
    final minVersion = platform.minVersion?.trim();
    final latestVersion = platform.latestVersion?.trim();

    var requirement = AppUpdateRequirement.none;
    String? blockingVersion;

    if (minVersion != null &&
        minVersion.isNotEmpty &&
        AppVersionCompare.isOlderThan(installedVersion, minVersion)) {
      requirement = AppUpdateRequirement.required;
      blockingVersion = minVersion;
    } else if (platform.minBuildNumber != null &&
        installedBuild < platform.minBuildNumber!) {
      requirement = AppUpdateRequirement.required;
      blockingVersion = minVersion ?? 'build ${platform.minBuildNumber}';
    } else if (latestVersion != null &&
        latestVersion.isNotEmpty &&
        AppVersionCompare.isOlderThan(installedVersion, latestVersion)) {
      final showOptional = await _shouldShowOptionalUpdate(latestVersion);
      if (showOptional) {
        requirement = AppUpdateRequirement.optional;
        blockingVersion = latestVersion;
      }
    }

    return AppUpdateCheckResult(
      requirement: requirement,
      installedVersion: installedVersion,
      installedBuildNumber: installedBuild,
      policy: resolvedPolicy,
      updateUrl: updateUrl,
      targetVersionLabel: blockingVersion,
    );
  }

  Future<void> recordOptionalUpdateDismissed(String latestVersion) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_optionalDismissVersionKey, latestVersion.trim());
    await prefs.setInt(
      _optionalDismissAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<bool> _shouldShowOptionalUpdate(String latestVersion) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissedFor = prefs.getString(_optionalDismissVersionKey)?.trim();
    if (dismissedFor != latestVersion.trim()) return true;
    final dismissedAtMs = prefs.getInt(_optionalDismissAtKey);
    if (dismissedAtMs == null) return true;
    final dismissedAt = DateTime.fromMillisecondsSinceEpoch(dismissedAtMs);
    return DateTime.now().difference(dismissedAt) >= _optionalReshowAfter;
  }

  Future<void> _cachePolicy(AppVersionPolicy policy) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(policy.toCacheJson()));
    } catch (e, st) {
      developer.log(
        'version_policy cache write failed',
        name: 'vyooo.version',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<AppVersionPolicy?> _readCachedPolicy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return AppVersionPolicy.fromMap(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }
}

@immutable
class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.requirement,
    this.installedVersion,
    this.installedBuildNumber,
    this.policy,
    this.updateUrl,
    this.targetVersionLabel,
  });

  final AppUpdateRequirement requirement;
  final String? installedVersion;
  final int? installedBuildNumber;
  final AppVersionPolicy? policy;
  final String? updateUrl;
  final String? targetVersionLabel;

  bool get blocksApp => requirement == AppUpdateRequirement.required;
}
