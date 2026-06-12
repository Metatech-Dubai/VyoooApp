import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Keeps local MP4 copies of the first feed reels so they play with no internet.
///
/// Storage lives in the app-support sandbox (`feed_offline_videos/`) and is
/// strictly bounded: at most [maxCachedVideos] files, each at most
/// [maxBytesPerVideo]. Files for reels that left the feed head are evicted on
/// every [syncForFeed]. This cache is independent from user-initiated
/// downloads (ReelDownloadService) and never surfaces in the Downloads UI.
class FeedOfflineVideoCache {
  FeedOfflineVideoCache._();
  static final FeedOfflineVideoCache instance = FeedOfflineVideoCache._();

  /// Product requirement: the next 10 posts must be viewable offline.
  static const int maxCachedVideos = 10;

  /// Guard against pathological files filling the sandbox (reels are short).
  static const int maxBytesPerVideo = 120 * 1024 * 1024;

  static final RegExp _streamManifestPattern = RegExp(
    r'^https?:\/\/[^\/]+\/([^\/]+)\/manifest\/video\.m3u8$',
    caseSensitive: false,
  );

  Directory? _dir;
  bool _syncInProgress = false;

  /// In-memory index of verified local files, keyed by cache key.
  final Map<String, String> _localPaths = {};
  bool _indexLoaded = false;
  Future<void>? _indexLoading;

  Future<Directory> _cacheDir() async {
    final cached = _dir;
    if (cached != null) return cached;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/feed_offline_videos');
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
          // Stale partial download from a previous run.
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

  /// Local playable copy for [videoUrl], or null when not cached.
  Future<File?> localFileFor(String videoUrl) async {
    final key = _cacheKeyFor(videoUrl);
    if (key == null) return null;
    await _ensureIndexLoaded();
    final path = _localPaths[key];
    if (path == null) return null;
    final file = File(path);
    if (await file.exists()) return file;
    _localPaths.remove(key);
    return null;
  }

  /// Aligns the cache with the first [maxCachedVideos] playable reels of the
  /// feed: downloads missing videos + thumbnails, evicts everything else.
  ///
  /// Fire-and-forget; safe to call repeatedly (overlapping calls no-op).
  Future<void> syncForFeed(List<Map<String, dynamic>> reels) async {
    if (_syncInProgress) return;
    _syncInProgress = true;
    try {
      await _ensureIndexLoaded();
      final targets = _targetsFromFeed(reels);
      await _evictExcept(targets.keys.toSet());
      for (final entry in targets.entries) {
        if (!_localPaths.containsKey(entry.key)) {
          await _download(entry.key, entry.value);
        }
      }
      unawaited(_warmThumbnails(reels));
    } catch (e) {
      debugPrint('FeedOfflineVideoCache sync failed: $e');
    } finally {
      _syncInProgress = false;
    }
  }

  /// cacheKey → downloadable MP4 url for the first playable video reels.
  Map<String, String> _targetsFromFeed(List<Map<String, dynamic>> reels) {
    final out = <String, String>{};
    for (final reel in reels) {
      if (out.length >= maxCachedVideos) break;
      final mediaType =
          ((reel['mediaType'] as String?) ?? 'video').toLowerCase();
      if (mediaType != 'video') continue;
      final videoUrl = ((reel['videoUrl'] as String?) ?? '').trim();
      final key = _cacheKeyFor(videoUrl);
      final downloadUrl = _downloadUrlFor(videoUrl);
      if (key == null || downloadUrl == null) continue;
      out.putIfAbsent(key, () => downloadUrl);
    }
    return out;
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

  Future<void> _download(String key, String url) async {
    final dir = await _cacheDir();
    final partFile = File('${dir.path}/$key.part');
    http.StreamedResponse? response;
    final client = http.Client();
    try {
      response = await client
          .send(http.Request('GET', Uri.parse(url)))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        // e.g. MP4 downloads not enabled for this video — skip silently.
        return;
      }
      final contentLength = response.contentLength ?? 0;
      if (contentLength > maxBytesPerVideo) return;

      final sink = partFile.openWrite();
      var written = 0;
      try {
        await for (final chunk in response.stream
            .timeout(const Duration(seconds: 30))) {
          written += chunk.length;
          if (written > maxBytesPerVideo) {
            throw const FileSystemException('feed offline video too large');
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

  /// Warms the shared image cache so thumbnails/avatars render offline.
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
      } catch (_) {
        // Thumbnail warm-up is best effort.
      }
    }
  }

  /// Stable file key per video. Cloudflare Stream reels key by video id so the
  /// HLS url and its MP4 variant map to the same cached file.
  static String? _cacheKeyFor(String videoUrl) {
    final url = videoUrl.trim();
    if (url.isEmpty) return null;
    final m = _streamManifestPattern.firstMatch(url);
    if (m != null) return m.group(1);
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return null;
    return md5.convert(utf8.encode(url)).toString();
  }

  /// Progressive-download url for [videoUrl], or null when the source cannot
  /// be fetched as a single file (unknown formats).
  static String? _downloadUrlFor(String videoUrl) {
    final url = videoUrl.trim();
    final m = _streamManifestPattern.firstMatch(url);
    if (m != null) {
      final videoId = m.group(1)!;
      return 'https://videodelivery.net/$videoId/downloads/default.mp4';
    }
    final lower = url.toLowerCase();
    if (lower.endsWith('.mp4') || lower.endsWith('.mov')) return url;
    return null;
  }
}
