import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'feed_offline_video_cache.dart';

/// Prefetches VR / 360° MP4s so native playback starts from disk, not the network.
class VrVideoCacheService {
  VrVideoCacheService._();
  static final VrVideoCacheService instance = VrVideoCacheService._();

  final FeedOfflineVideoCache _cache = FeedOfflineVideoCache.vrInstance;
  final Set<String> _prefetchInFlight = <String>{};

  Future<void> syncForFeed(List<Map<String, dynamic>> reels) async {
    await _cache.syncForFeed(reels);
  }

  void prefetch(String videoUrl) {
    final url = videoUrl.trim();
    if (url.isEmpty) return;
    final key = FeedOfflineVideoCache.cacheKeyFor(url);
    final downloadUrl = FeedOfflineVideoCache.downloadUrlFor(url);
    if (key == null || downloadUrl == null) return;
    unawaited(_prefetchByKey(key, downloadUrl));
  }

  Future<void> _prefetchByKey(String key, String downloadUrl) async {
    if (_prefetchInFlight.contains(key)) return;
    final existing = await _cache.localFileForKey(key);
    if (existing != null) return;
    _prefetchInFlight.add(key);
    try {
      await _cache.downloadToCache(key: key, url: downloadUrl);
    } catch (e) {
      debugPrint('VrVideoCacheService prefetch failed ($key): $e');
    } finally {
      _prefetchInFlight.remove(key);
    }
  }

  Future<File?> localFileFor(String videoUrl) => _cache.localFileFor(videoUrl);

  bool isPrefetching(String videoUrl) {
    final key = FeedOfflineVideoCache.cacheKeyFor(videoUrl.trim());
    return key != null && _prefetchInFlight.contains(key);
  }
}
