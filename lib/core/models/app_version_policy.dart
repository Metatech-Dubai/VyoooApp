import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Remote policy from Firestore `app_config/version_policy`.
@immutable
class AppVersionPolicy {
  const AppVersionPolicy({
    required this.enabled,
    required this.title,
    required this.message,
    required this.updateButtonLabel,
    required this.laterButtonLabel,
    required this.ios,
    required this.android,
  });

  final bool enabled;
  final String title;
  final String message;
  final String updateButtonLabel;
  final String laterButtonLabel;
  final AppVersionPlatformPolicy ios;
  final AppVersionPlatformPolicy android;

  static const String firestoreCollection = 'app_config';
  static const String firestoreDocumentId = 'version_policy';

  factory AppVersionPolicy.fromMap(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return AppVersionPolicy.disabled();
    }
    final iosMap = _mapOrEmpty(data['ios']);
    final androidMap = _mapOrEmpty(data['android']);
    return AppVersionPolicy(
      enabled: data['enabled'] == true,
      title: _string(data['title'], 'Update required'),
      message: _string(
        data['message'],
        'A new version of Vyooo is available. Please update to continue.',
      ),
      updateButtonLabel: _string(data['updateButtonLabel'], 'Update'),
      laterButtonLabel: _string(data['laterButtonLabel'], 'Later'),
      ios: AppVersionPlatformPolicy.fromMap(
        iosMap,
        flatPrefix: 'Ios',
        parent: data,
        fallbackUpdateUrl: _iosStoreUrlFromParent(data),
      ),
      android: AppVersionPlatformPolicy.fromMap(
        androidMap,
        flatPrefix: 'Android',
        parent: data,
        fallbackUpdateUrl: _defaultAndroidStoreUrl,
      ),
    );
  }

  factory AppVersionPolicy.disabled() {
    return AppVersionPolicy(
      enabled: false,
      title: '',
      message: '',
      updateButtonLabel: 'Update',
      laterButtonLabel: 'Later',
      ios: AppVersionPlatformPolicy.empty(),
      android: AppVersionPlatformPolicy.empty(),
    );
  }

  AppVersionPlatformPolicy platformPolicy() {
    if (kIsWeb) return AppVersionPlatformPolicy.empty();
    if (Platform.isIOS) return ios;
    if (Platform.isAndroid) return android;
    return AppVersionPlatformPolicy.empty();
  }

  Map<String, dynamic> toCacheJson() => {
    'enabled': enabled,
    'title': title,
    'message': message,
    'updateButtonLabel': updateButtonLabel,
    'laterButtonLabel': laterButtonLabel,
    'ios': ios.toCacheJson(),
    'android': android.toCacheJson(),
  };

  static String _string(Object? value, String fallback) {
    final s = value?.toString().trim();
    if (s == null || s.isEmpty) return fallback;
    return s;
  }

  static Map<String, dynamic> _mapOrEmpty(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const {};
  }

  /// Play Store listing for [com.vyooo].
  static const String _defaultAndroidStoreUrl =
      'https://play.google.com/store/apps/details?id=com.vyooo';

  static String _iosStoreUrlFromParent(Map<String, dynamic> data) {
    final storeId = data['iosAppStoreId']?.toString().trim();
    if (storeId != null && storeId.isNotEmpty) {
      return 'https://apps.apple.com/app/id$storeId';
    }
    return '';
  }
}

@immutable
class AppVersionPlatformPolicy {
  const AppVersionPlatformPolicy({
    this.minVersion,
    this.latestVersion,
    this.minBuildNumber,
    this.updateUrl,
  });

  final String? minVersion;
  final String? latestVersion;
  final int? minBuildNumber;
  final String? updateUrl;

  factory AppVersionPlatformPolicy.empty() {
    return const AppVersionPlatformPolicy();
  }

  factory AppVersionPlatformPolicy.fromMap(
    Map<String, dynamic> nested, {
    required String flatPrefix,
    required Map<String, dynamic> parent,
    required String fallbackUpdateUrl,
  }) {
    String? pickVersion(String nestedKey, String flatKey) {
      final fromNested = nested[nestedKey]?.toString().trim();
      if (fromNested != null && fromNested.isNotEmpty) return fromNested;
      final fromFlat = parent[flatKey]?.toString().trim();
      if (fromFlat != null && fromFlat.isNotEmpty) return fromFlat;
      return null;
    }

    int? pickBuild() {
      final nestedBuild = nested['minBuildNumber'];
      if (nestedBuild is int) return nestedBuild;
      if (nestedBuild is num) return nestedBuild.toInt();
      final flatKey = 'minBuildNumber$flatPrefix';
      final flatBuild = parent[flatKey];
      if (flatBuild is int) return flatBuild;
      if (flatBuild is num) return flatBuild.toInt();
      return null;
    }

    String? pickUrl() {
      final nestedUrl = nested['updateUrl']?.toString().trim();
      if (nestedUrl != null && nestedUrl.isNotEmpty) return nestedUrl;
      final flatUrl = parent['updateUrl$flatPrefix']?.toString().trim();
      if (flatUrl != null && flatUrl.isNotEmpty) return flatUrl;
      if (fallbackUpdateUrl.isNotEmpty) return fallbackUpdateUrl;
      return null;
    }

    return AppVersionPlatformPolicy(
      minVersion: pickVersion('minVersion', 'minVersion$flatPrefix'),
      latestVersion: pickVersion('latestVersion', 'latestVersion$flatPrefix'),
      minBuildNumber: pickBuild(),
      updateUrl: pickUrl(),
    );
  }

  Map<String, dynamic> toCacheJson() => {
    if (minVersion != null) 'minVersion': minVersion,
    if (latestVersion != null) 'latestVersion': latestVersion,
    if (minBuildNumber != null) 'minBuildNumber': minBuildNumber,
    if (updateUrl != null) 'updateUrl': updateUrl,
  };
}
