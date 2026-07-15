import 'package:shared_preferences/shared_preferences.dart';

import '../../../screens/profile/profile_figma_tokens.dart';

/// Persists profile grid column density (Instagram-style pinch zoom).
abstract final class ProfileGridDensityService {
  ProfileGridDensityService._();

  static const String _prefsKey = 'profile_grid_cross_axis_count';

  static const int minColumns = 1;
  static const int maxColumns = 3;

  /// Spread fingers apart past this → fewer columns (larger tiles).
  static const double pinchOutThreshold = 1.1;

  /// Pinch together past this → more columns (smaller tiles).
  static const double pinchInThreshold = 0.9;

  static int get defaultColumns => ProfileFigmaTokens.contentGridCrossAxisCount;

  static int clampColumns(int value) {
    return value.clamp(minColumns, maxColumns);
  }

  static Future<int> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_prefsKey);
      if (saved == null) return defaultColumns;
      return clampColumns(saved);
    } catch (_) {
      return defaultColumns;
    }
  }

  static Future<void> save(int columns) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKey, clampColumns(columns));
    } catch (_) {
      // Non-critical preference; ignore write failures.
    }
  }
}
