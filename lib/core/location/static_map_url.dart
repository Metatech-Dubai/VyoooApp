import '../config/app_config.dart';

/// Google Static Maps preview URLs (requires Maps Static API on the key).
/// Onboarding uses OpenStreetMap tiles instead (`location_map_preview.dart`).
abstract final class StaticMapUrl {
  StaticMapUrl._();

  static String preview({
    required double latitude,
    required double longitude,
    int width = 600,
    int height = 280,
    int zoom = 14,
  }) {
    final w = width.clamp(200, 640);
    final h = height.clamp(120, 400);
    return Uri.https(
      'maps.googleapis.com',
      '/maps/api/staticmap',
      {
        'center': '$latitude,$longitude',
        'zoom': '$zoom',
        'size': '${w}x$h',
        'scale': '2',
        'maptype': 'roadmap',
        'markers': 'color:red|$latitude,$longitude',
        'key': AppConfig.googlePlacesApiKey,
      },
    ).toString();
  }
}
