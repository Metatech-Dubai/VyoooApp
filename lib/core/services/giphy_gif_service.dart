import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ChatGif {
  const ChatGif({
    required this.id,
    required this.url,
    required this.previewUrl,
    this.width,
    this.height,
  });

  final String id;
  final String url;
  final String previewUrl;
  final int? width;
  final int? height;
}

/// Giphy GIF search for chat. Requires [AppConfig.giphyApiKey].
/// Tenor no longer accepts new API clients (Jan 2026); Giphy is the replacement.
/// Get a free key: https://developers.giphy.com/dashboard/
class GiphyGifService {
  GiphyGifService._();
  static final GiphyGifService _instance = GiphyGifService._();
  factory GiphyGifService() => _instance;

  static const String _base = 'https://api.giphy.com/v1/gifs';

  bool get isAvailable => AppConfig.isGiphyGifSearchAvailable;

  Future<List<ChatGif>> search(String query, {int limit = 24}) async {
    if (!isAvailable) return [];
    final trimmed = query.trim();
    if (trimmed.isEmpty) return trending(limit: limit);
    return _fetch(
      '$_base/search'
      '?api_key=${AppConfig.giphyApiKey}'
      '&q=${Uri.encodeQueryComponent(trimmed)}'
      '&limit=${limit.clamp(1, 50)}'
      '&rating=g',
    );
  }

  Future<List<ChatGif>> trending({int limit = 24}) async {
    if (!isAvailable) return [];
    return _fetch(
      '$_base/trending'
      '?api_key=${AppConfig.giphyApiKey}'
      '&limit=${limit.clamp(1, 50)}'
      '&rating=g',
    );
  }

  Future<List<ChatGif>> _fetch(String url) async {
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body);
      if (body is! Map<String, dynamic>) return [];
      final data = body['data'];
      if (data is! List) return [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(_parseResult)
          .whereType<ChatGif>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  ChatGif? _parseResult(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final images = json['images'];
    if (images is! Map<String, dynamic>) return null;

    final full =
        _imageUrl(images['downsized']) ??
        _imageUrl(images['fixed_height']) ??
        _imageUrl(images['original']);
    if (full == null) return null;

    final preview =
        _imageUrl(images['fixed_height_small']) ??
        _imageUrl(images['preview_gif']) ??
        full;

    final dims =
        _imageDims(images['downsized']) ??
        _imageDims(images['fixed_height']) ??
        _imageDims(images['original']);

    return ChatGif(
      id: id,
      url: full.url,
      previewUrl: preview.url,
      width: dims?.width,
      height: dims?.height,
    );
  }

  _GiphyImage? _imageUrl(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final url = raw['url'];
    if (url is! String || url.isEmpty) return null;
    return _GiphyImage(url: url);
  }

  _GiphyDims? _imageDims(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final w = int.tryParse('${raw['width'] ?? ''}');
    final h = int.tryParse('${raw['height'] ?? ''}');
    if (w == null || h == null) return null;
    return _GiphyDims(width: w, height: h);
  }
}

class _GiphyImage {
  const _GiphyImage({required this.url});

  final String url;
}

class _GiphyDims {
  const _GiphyDims({required this.width, required this.height});

  final int width;
  final int height;
}
