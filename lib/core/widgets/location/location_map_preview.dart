import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Map preview using OpenStreetMap raster tiles (no Google Static Maps API).
class LocationMapPreview extends StatelessWidget {
  const LocationMapPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    this.height = 168,
    this.zoom = 14,
  });

  final double latitude;
  final double longitude;
  final double height;
  final int zoom;

  static const _osmUserAgent = 'Vyooo/1.1 (profile location preview)';

  @override
  Widget build(BuildContext context) {
    final centerX = _lonToTileX(longitude, zoom);
    final centerY = _latToTileY(latitude, zoom);

    return ClipRRect(
      borderRadius: AppRadius.inputRadius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Row(
              children: [
                for (var dx = -1; dx <= 1; dx++)
                  Expanded(
                    child: Column(
                      children: [
                        for (var dy = -1; dy <= 1; dy++)
                          Expanded(
                            child: _OsmTile(
                              zoom: zoom,
                              x: centerX + dx,
                              y: centerY + dy,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            Center(
              child: Icon(
                Icons.location_on,
                size: 40,
                color: AppColors.brandPink,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            Positioned(
              right: AppSpacing.xs,
              bottom: 2,
              child: Text(
                '© OpenStreetMap',
                style: AppTypography.onboardingPrivacyBody.copyWith(
                  fontSize: 9,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static int _lonToTileX(double lon, int z) {
    return ((lon + 180) / 360 * math.pow(2, z)).floor();
  }

  static int _latToTileY(double lat, int z) {
    final latRad = lat * math.pi / 180;
    final n = math.pow(2, z).toDouble();
    return ((1 -
                math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
            2 *
        n)
        .floor();
  }
}

class _OsmTile extends StatelessWidget {
  const _OsmTile({
    required this.zoom,
    required this.x,
    required this.y,
  });

  final int zoom;
  final int x;
  final int y;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: 'https://tile.openstreetmap.org/$zoom/$x/$y.png',
      httpHeaders: const {'User-Agent': LocationMapPreview._osmUserAgent},
      fit: BoxFit.cover,
      placeholder: (_, _) => ColoredBox(
        color: Colors.white.withValues(alpha: 0.06),
      ),
      errorWidget: (_, _, _) => ColoredBox(
        color: Colors.white.withValues(alpha: 0.08),
        child: Icon(
          Icons.broken_image_outlined,
          size: 18,
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}
