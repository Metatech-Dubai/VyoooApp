import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Keeps local MP4 copies of feed reels so they play without re-buffering.
///
/// [instance] — main feed (smaller files, more slots).
/// [vrInstance] — VR / 360° tab (larger files, fewer slots).
class FeedOfflineVideoCache {
  FeedOfflineVideoCache._(
    this._subdirName,
    this.maxCachedVideos,
    this.maxBytesPerVideo,
  );

  static final FeedOfflineVideoCache instance = FeedOfflineVideoCache._(
    'feed_offline_videos',
    10,
    120 * 1024 * 1024,
  );

  static final FeedOfflineVideoCache vrInstance = FeedOfflineVideoCache._(
    'vr_offline_videos',
    5,
    400 * 1024 * 1024,
  );

  final String _subdirName;
  final int maxCachedVideos;
  final int maxBytesPerVideo;

  static final RegExp streamManifestPattern = RegExp(
    r'^https?:\/\/[^\/]+\/([^\/]+)\/manifest\/video\.m3u8$',
    caseSensitive: false,
  );

  Directory? _dir;
  bool _syncInProgress = false;

  final Map<String, String> _localPaths = {};
  bool _indexLoaded = false;
  Future<void>? _indexLoading;

  Future<Directory> _cacheDir() async {
    final cached = _dir;
    if (cached != null) return cached;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/$_subdirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dir = dir;
    return dir;
  }

  Future<void> _ensureIndexLoaded() {
    if (_indexLoaded) return Future.value();
    return _indexLoading ??= _loadIndex();
  }

  Future<void> _loadIndex() async {
    try {
      final dir = await _cacheDir();
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!name.endsWith('.mp4')) {
          unawaited(entity.delete().catchError((Object _) => entity));
          continue;
        }
        final key = name.substring(0, name.length - 4);
        _localPaths[key] = entity.path;
      }
    } catch (e) {
      debugPrint('FeedOfflineVideoCache index load failed: $e');
    } finally {
      _indexLoaded = true;
      _indexLoading = null;
    }
  }

  Future<File?> localFileFor(String videoUrl) async {
    final key = cacheKeyFor(videoUrl);
    if (key == null) return null;
    return localFileForKey(key);
  }

  Future<File?> localFileForKey(String key) async {
    await _ensureIndexLoaded();
    final path = _localPaths[key];
    if (path == null) return null;
    final file = File(path);
    if (await file.exists()) return file;
    _localPaths.remove(key);
    return null;
  }

  Future<void> syncForFeed(List<Map<String, dynamic>> reels) async {
    if (_syncInProgress) return;
    _syncInProgress = true;
    try {
      await _ensureIndexLoaded();
      final targets = targetsFromReels(reels);
      await _evictExcept(targets.keys.toSet());
      for (final entry in targets.entries) {
        if (!_localPaths.containsKey(entry.key)) {
          await downloadToCache(key: entry.key, url: entry.value);
        }
      }
      if (identical(this, instance)) {
        unawaited(_warmThumbnails(reels));
      }
    } catch (e) {
      debugPrint('FeedOfflineVideoCache sync failed: $e');
    } finally {
      _syncInProgress = false;
    }
  }

  Map<String, String> targetsFromReels(
    List<Map<String, dynamic>> reels, {
    int? maxVideos,
    int? maxBytesPerVideo,
  }) {
    final limit = maxVideos ?? maxCachedVideos;
    final out = <String, String>{};
    for (final reel in reels) {
      if (out.length >= limit) break;
      final mediaType =
          ((reel['mediaType'] as String?) ?? 'video').toLowerCase();
      if (mediaType != 'video') continue;
      final videoUrl = ((reel['videoUrl'] as String?) ?? '').trim();
      final key = cacheKeyFor(videoUrl);
      final downloadUrl = downloadUrlFor(videoUrl);
      if (key == null || downloadUrl == null) continue;
      out.putIfAbsent(key, () => downloadUrl);
    }
    return out;
  }

  Future<void> downloadToCache({
    required String key,
    required String url,
    int? maxBytes,
  }) async {
    final byteLimit = maxBytes ?? maxBytesPerVideo;
    final dir = await _cacheDir();
    final partFile = File('${dir.path}/$key.part');
    final client = http.Client();
    try {
      final response = await client
          .send(http.Request('GET', Uri.parse(url)))
          .timeout(const Duration(seconds: 45));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return;
      }
      final contentLength = response.contentLength ?? 0;
      if (contentLength > byteLimit) return;

      final sink = partFile.openWrite();
      var written = 0;
      try {
        await for (final chunk in response.stream
            .timeout(const Duration(seconds: 90))) {
          written += chunk.length;
          if (written > byteLimit) {
            throw const FileSystemException('offline video too large');
          }
          sink.add(chunk);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      final file = File('${dir.path}/$key.mp4');
      await partFile.rename(file.path);
      _localPaths[key] = file.path;
    } catch (e) {
      debugPrint('FeedOfflineVideoCache download failed ($key): $e');
      try {
        if (await partFile.exists()) await partFile.delete();
      } catch (_) {}
    } finally {
      client.close();
    }
  }

  Future<void> _evictExcept(Set<String> keepKeys) async {
    final stale =
        _localPaths.keys.where((k) => !keepKeys.contains(k)).toList();
    for (final key in stale) {
      final path = _localPaths.remove(key);
      if (path == null) continue;
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  Future<void> _warmThumbnails(List<Map<String, dynamic>> reels) async {
    final urls = <String>{};
    for (final reel in reels.take(maxCachedVideos)) {
      for (final field in const ['thumbnailUrl', 'imageUrl', 'avatarUrl']) {
        final url = ((reel[field] as String?) ?? '').trim();
        if (url.isNotEmpty && Uri.tryParse(url)?.hasScheme == true) {
          urls.add(url);
        }
      }
    }
    for (final url in urls) {
      try {
        await DefaultCacheManager().getSingleFile(url);
      } catch (_) {}
    }
  }

  static String? cacheKeyFor(String videoUrl) {
    final url = videoUrl.trim();
    if (url.isEmpty) return null;
    final m = streamManifestPattern.firstMatch(url);
    if (m != null) return m.group(1);
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return null;
    return md5.convert(utf8.encode(url)).toString();
  }

  static String? downloadUrlFor(String videoUrl) {
    final url = videoUrl.trim();
    final m = streamManifestPattern.firstMatch(url);
    if (m != null) {
      final videoId = m.group(1)!;
      return 'https://videodelivery.net/$videoId/downloads/default.mp4';
    }
    final lower = url.toLowerCase();
    if (lower.endsWith('.mp4') || lower.endsWith('.mov')) return url;
    return null;
  }
}
