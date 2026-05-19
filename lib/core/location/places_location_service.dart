import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/post_location_model.dart';

/// City + country/region parsed from Google address components.
class ParsedAddressParts {
  const ParsedAddressParts({
    required this.city,
    required this.countryOrRegion,
  });

  final String city;
  final String countryOrRegion;

  String get displayLabel {
    if (city.isEmpty) return countryOrRegion;
    if (countryOrRegion.isEmpty) return city;
    return '$city, $countryOrRegion';
  }
}

/// [PostLocation] plus fields for onboarding form autofill.
class ResolvedProfileLocation {
  const ResolvedProfileLocation({
    required this.location,
    required this.city,
    required this.countryOrRegion,
  });

  final PostLocation location;
  final String city;
  final String countryOrRegion;

  /// Two-line address for onboarding UI (city / region).
  String get addressLines {
    if (countryOrRegion.isEmpty) return city;
    return '$city\n$countryOrRegion';
  }
}

/// Google Places autocomplete row.
class PlacePrediction {
  const PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
}

/// Shared search / GPS / resolve logic for profile and post location pickers.
class PlacesLocationService {
  PlacesLocationService._();

  static String newSessionToken() =>
      DateTime.now().millisecondsSinceEpoch.toString();

  /// Formats a single-line Google address into two lines when possible.
  static String formatAddressLinesFromText(String formatted) {
    final value = formatted.trim();
    if (value.isEmpty) return '';
    final parts =
        value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (parts.length <= 1) return value;
    if (parts.length == 2) return '${parts[0]}\n${parts[1]}';
    return '${parts.first}\n${parts.sublist(1).join(', ')}';
  }

  static String formatAddressLinesFromPostLocation(PostLocation location) {
    final address = (location.address ?? '').trim();
    if (address.isNotEmpty) {
      return formatAddressLinesFromText(address);
    }
    return location.name.trim();
  }

  /// Place suggestions; prefers cities/regions, falls back to broader search.
  static Future<List<PlacePrediction>> fetchPredictions({
    required String input,
    required String sessionToken,
  }) async {
    final query = input.trim();
    if (query.isEmpty) return [];

    var results = await _autocomplete(
      input: query,
      sessionToken: sessionToken,
      types: '(cities)',
    );
    if (results.isEmpty) {
      results = await _autocomplete(
        input: query,
        sessionToken: sessionToken,
      );
    }
    return results;
  }

  static Future<List<PlacePrediction>> _autocomplete({
    required String input,
    required String sessionToken,
    String? types,
  }) async {
    final params = <String, String>{
      'input': input,
      'key': AppConfig.googlePlacesApiKey,
      'sessiontoken': sessionToken,
    };
    if (types != null && types.isNotEmpty) {
      params['types'] = types;
    }
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      params,
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw PlacesLocationException('Search failed. Try again.');
    }
    final body = json.decode(res.body) as Map<String, dynamic>;
    final status = body['status'] as String? ?? '';
    if (status == 'ZERO_RESULTS') return [];
    if (status != 'OK') {
      final message = body['error_message'] as String? ?? status;
      throw PlacesLocationException(
        message.isNotEmpty
            ? 'Search unavailable ($message). Use the fields below.'
            : 'Search unavailable. Use the fields below.',
      );
    }
    return (body['predictions'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(
          (p) => PlacePrediction(
            placeId: p['place_id'] as String? ?? '',
            description: p['description'] as String? ?? '',
            mainText:
                (p['structured_formatting'] as Map?)?['main_text'] as String? ??
                '',
            secondaryText:
                (p['structured_formatting'] as Map?)?['secondary_text']
                    as String? ??
                '',
          ),
        )
        .where((p) => p.placeId.isNotEmpty)
        .toList();
  }

  /// Parses Google `address_components` into city and country/region.
  static ParsedAddressParts parseAddressComponents(List<dynamic> raw) {
    String? locality;
    String? postalTown;
    String? sublocality;
    String? admin2;
    String? admin1;
    String? country;

    for (final item in raw) {
      if (item is! Map) continue;
      final comp = Map<String, dynamic>.from(item);
      final types =
          (comp['types'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final long = (comp['long_name'] as String?)?.trim() ?? '';
      if (long.isEmpty) continue;

      if (types.contains('locality')) locality = long;
      if (types.contains('postal_town')) postalTown ??= long;
      if (types.contains('sublocality') ||
          types.contains('sublocality_level_1')) {
        sublocality ??= long;
      }
      if (types.contains('administrative_area_level_2')) admin2 = long;
      if (types.contains('administrative_area_level_1')) admin1 = long;
      if (types.contains('country')) country = long;
    }

    final city =
        locality ?? postalTown ?? sublocality ?? admin2 ?? admin1 ?? '';

    final regionParts = <String>[];
    if (admin1 != null && admin1.isNotEmpty && admin1 != city) {
      regionParts.add(admin1);
    }
    if (country != null && country.isNotEmpty && !regionParts.contains(country)) {
      regionParts.add(country);
    }

    return ParsedAddressParts(
      city: city,
      countryOrRegion: regionParts.join(', '),
    );
  }

  static ResolvedProfileLocation _fromGeocodeResult({
    required Map<String, dynamic> result,
    required double latitude,
    required double longitude,
    required String source,
    String? placeId,
    String fallbackName = '',
  }) {
    final formatted = (result['formatted_address'] as String?)?.trim() ?? '';
    final components = result['address_components'] as List? ?? [];
    var parts = parseAddressComponents(components);

    if (parts.city.isEmpty && formatted.contains(',')) {
      final split = formatted.split(',').map((s) => s.trim()).toList();
      if (split.isNotEmpty) {
        parts = ParsedAddressParts(
          city: split.first,
          countryOrRegion: split.length > 1 ? split.sublist(1).join(', ') : '',
        );
      }
    }
    if (parts.city.isEmpty && fallbackName.isNotEmpty) {
      parts = ParsedAddressParts(city: fallbackName, countryOrRegion: '');
    }

    final display = parts.displayLabel.isNotEmpty
        ? parts.displayLabel
        : (formatted.isNotEmpty ? formatted : fallbackName);

    return ResolvedProfileLocation(
      city: parts.city,
      countryOrRegion: parts.countryOrRegion,
      location: PostLocation(
        placeId: placeId,
        name: display,
        address: formatted.isNotEmpty ? formatted : display,
        latitude: latitude,
        longitude: longitude,
        source: source,
      ),
    );
  }

  static Map<String, dynamic>? _bestGeocodeResult(List<dynamic> results) {
    for (final raw in results) {
      if (raw is! Map<String, dynamic>) continue;
      final components = raw['address_components'] as List? ?? [];
      final parts = parseAddressComponents(components);
      if (parts.city.isNotEmpty) return raw;
    }
    if (results.isEmpty) return null;
    final first = results.first;
    return first is Map<String, dynamic> ? first : null;
  }

  static Future<ResolvedProfileLocation> resolvePrediction({
    required PlacePrediction prediction,
    required String sessionToken,
  }) async {
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/details/json',
        {
          'place_id': prediction.placeId,
          'fields':
              'place_id,name,formatted_address,geometry,address_components',
          'key': AppConfig.googlePlacesApiKey,
          'sessiontoken': sessionToken,
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        final result = body['result'] as Map<String, dynamic>?;
        if (result != null) {
          final geo = result['geometry'] as Map<String, dynamic>?;
          final loc = geo?['location'] as Map<String, dynamic>?;
          final lat = (loc?['lat'] as num?)?.toDouble() ?? 0.0;
          final lng = (loc?['lng'] as num?)?.toDouble() ?? 0.0;
          final fallback = prediction.mainText.trim().isNotEmpty
              ? prediction.mainText.trim()
              : prediction.description.trim();
          return _fromGeocodeResult(
            result: result,
            latitude: lat,
            longitude: lng,
            source: 'search',
            placeId: prediction.placeId,
            fallbackName: fallback,
          );
        }
      }
    } catch (_) {}

    final fallback = prediction.mainText.trim().isNotEmpty
        ? prediction.mainText.trim()
        : prediction.description.trim();
    final region = prediction.secondaryText.trim();
    return ResolvedProfileLocation(
      city: fallback,
      countryOrRegion: region,
      location: PostLocation(
        placeId: prediction.placeId,
        name: region.isNotEmpty ? '$fallback, $region' : fallback,
        address: prediction.description,
        source: 'search',
      ),
    );
  }

  /// For upload sheet and other callers that only need [PostLocation].
  static Future<PostLocation> resolvePredictionLocation({
    required PlacePrediction prediction,
    required String sessionToken,
  }) async {
    final resolved = await resolvePrediction(
      prediction: prediction,
      sessionToken: sessionToken,
    );
    return resolved.location;
  }

  static PostLocation manualLocation({
    required String city,
    String? countryOrRegion,
  }) {
    final cityText = city.trim();
    final regionText = (countryOrRegion ?? '').trim();
    final display = regionText.isNotEmpty ? '$cityText, $regionText' : cityText;
    return PostLocation(
      name: display,
      address: display,
      source: 'manual',
    );
  }

  static Future<ResolvedProfileLocation> currentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw PlacesLocationException(
        'Location services are disabled. Enable them in Settings or search for your city.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw PlacesLocationException(
        'Location permission denied. Search for your city instead.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 10),
      ),
    );
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/geocode/json',
        {
          'latlng': '${position.latitude},${position.longitude}',
          'key': AppConfig.googlePlacesApiKey,
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        final results = body['results'] as List? ?? [];
        final best = _bestGeocodeResult(results);
        if (best != null) {
          return _fromGeocodeResult(
            result: best,
            latitude: position.latitude,
            longitude: position.longitude,
            source: 'gps',
          );
        }
      }
    } catch (_) {}
    return ResolvedProfileLocation(
      city: '',
      countryOrRegion: '',
      location: PostLocation(
        name: 'Current location',
        latitude: position.latitude,
        longitude: position.longitude,
        source: 'gps',
      ),
    );
  }
}

class PlacesLocationException implements Exception {
  PlacesLocationException(this.message);
  final String message;

  @override
  String toString() => message;
}
