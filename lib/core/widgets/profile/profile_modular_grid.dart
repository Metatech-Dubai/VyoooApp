import 'package:flutter/material.dart';

import '../../models/reel_count_privacy.dart';
import '../../../screens/profile/profile_figma_tokens.dart';
import '../../utils/reel_engagement.dart';
import 'profile_grid_density_service.dart';
import 'profile_grid_layout_engine.dart';
import 'profile_grid_models.dart';
import 'profile_grid_posts.dart';
import 'profile_grid_tile.dart';
import 'profile_grid_title.dart';
import 'profile_span_grid_layout.dart';

/// Modular portrait grid (1×1 and optional 2×2) for profile Feed / VR / Saved tabs.
///
/// Pinch with two fingers to change column density (3 → 2 → 1), Instagram-style.
class ProfileModularGrid extends StatefulWidget {
  const ProfileModularGrid({
    super.key,
    required this.items,
    required this.onItemTap,
    this.onItemLongPress,
    this.layoutMode = ProfileGridLayoutMode.uniform,
    this.crossAxisCount = ProfileFigmaTokens.contentGridCrossAxisCount,
    this.gap = ProfileFigmaTokens.contentGridGap,
    this.tileAspectRatio = ProfileFigmaTokens.contentGridTileAspectRatio,
    this.minViewsForDouble = 0,
    this.padding = EdgeInsets.zero,
    this.enablePinchDensityZoom = true,
  });

  final List<ProfileGridItem> items;
  final void Function(int sourceIndex) onItemTap;
  final void Function(int sourceIndex)? onItemLongPress;
  final ProfileGridLayoutMode layoutMode;
  final int crossAxisCount;
  final double gap;
  /// Width divided by height (Figma ~132.49 / 165.61).
  final double tileAspectRatio;
  final int minViewsForDouble;
  final EdgeInsetsGeometry padding;

  /// When true, pinch in/out on the grid toggles between 1–3 columns.
  final bool enablePinchDensityZoom;

  @override
  State<ProfileModularGrid> createState() => _ProfileModularGridState();
}

class _ProfileModularGridState extends State<ProfileModularGrid> {
  static const _densityAnimationDuration = Duration(milliseconds: 220);

  late int _crossAxisCount;
  double _pinchScale = 1.0;

  @override
  void initState() {
    super.initState();
    _crossAxisCount = ProfileGridDensityService.clampColumns(
      widget.crossAxisCount,
    );
    if (widget.enablePinchDensityZoom) {
      _loadSavedDensity();
    }
  }

  @override
  void didUpdateWidget(ProfileModularGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enablePinchDensityZoom &&
        widget.crossAxisCount != oldWidget.crossAxisCount) {
      _crossAxisCount = ProfileGridDensityService.clampColumns(
        widget.crossAxisCount,
      );
    }
  }

  Future<void> _loadSavedDensity() async {
    final saved = await ProfileGridDensityService.load();
    if (!mounted) return;
    setState(() => _crossAxisCount = saved);
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (!widget.enablePinchDensityZoom) return;
    _pinchScale = 1.0;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!widget.enablePinchDensityZoom || details.pointerCount < 2) return;
    _pinchScale = details.scale;
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (!widget.enablePinchDensityZoom) return;

    final scale = _pinchScale;
    _pinchScale = 1.0;

    var next = _crossAxisCount;
    if (scale >= ProfileGridDensityService.pinchOutThreshold) {
      next = ProfileGridDensityService.clampColumns(_crossAxisCount - 1);
    } else if (scale <= ProfileGridDensityService.pinchInThreshold) {
      next = ProfileGridDensityService.clampColumns(_crossAxisCount + 1);
    }

    if (next == _crossAxisCount) return;
    setState(() => _crossAxisCount = next);
    ProfileGridDensityService.save(next);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final viewsByIndex = List<int>.filled(widget.items.length, 0);
    final spanOverrideByIndex = List<ProfileGridSpanOverride>.filled(
      widget.items.length,
      ProfileGridSpanOverride.auto,
    );
    for (final item in widget.items) {
      if (item.sourceIndex >= 0 && item.sourceIndex < viewsByIndex.length) {
        viewsByIndex[item.sourceIndex] = item.views;
        spanOverrideByIndex[item.sourceIndex] = item.spanOverride;
      }
    }

    final placements = ProfileGridLayoutEngine.layout(
      itemCount: widget.items.length,
      viewsByIndex: viewsByIndex,
      mode: widget.layoutMode,
      minViewsForDouble: widget.minViewsForDouble,
      spanOverrideByIndex: spanOverrideByIndex,
    );

    final bySourceIndex = <int, ProfileGridItem>{
      for (final item in widget.items) item.sourceIndex: item,
    };

    final slots = ProfileSpanGridLayout.pack(
      placements: placements,
      crossAxisCount: _crossAxisCount,
    );
    if (slots.isEmpty) return const SizedBox.shrink();

    final grid = Padding(
      padding: widget.padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (!width.isFinite || width <= 0) {
            return const SizedBox.shrink();
          }

          final cellWidth =
              (width - widget.gap * (_crossAxisCount - 1)) / _crossAxisCount;
          final cellHeight = cellWidth / widget.tileAspectRatio;
          final rowCount = ProfileSpanGridLayout.rowCount(slots);
          final height = rowCount * cellHeight + (rowCount - 1) * widget.gap;

          return AnimatedSize(
            duration: _densityAnimationDuration,
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: height,
              width: width,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  const Positioned.fill(
                    child: ColoredBox(
                      color: ProfileFigmaTokens.contentSurface,
                    ),
                  ),
                  for (final slot in slots)
                    _positionedTile(
                      slot: slot,
                      cellWidth: cellWidth,
                      cellHeight: cellHeight,
                      gap: widget.gap,
                      gridWidth: width,
                      gridHeight: height,
                      crossAxisCount: _crossAxisCount,
                      rowCount: rowCount,
                      gridItem: bySourceIndex[slot.placement.sourceIndex],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (!widget.enablePinchDensityZoom) return grid;

    return GestureDetector(
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      behavior: HitTestBehavior.translucent,
      child: grid,
    );
  }

  Widget _positionedTile({
    required ProfileSpanGridSlot slot,
    required double cellWidth,
    required double cellHeight,
    required double gap,
    required double gridWidth,
    required double gridHeight,
    required int crossAxisCount,
    required int rowCount,
    required ProfileGridItem? gridItem,
  }) {
    if (gridItem == null) return const SizedBox.shrink();

    final left = slot.column * (cellWidth + gap);
    final top = slot.row * (cellHeight + gap);
    final spansLastColumn = slot.column + slot.columnSpan == crossAxisCount;
    final spansLastRow = slot.row + slot.rowSpan == rowCount;
    final tileWidth = spansLastColumn
        ? gridWidth - left
        : slot.columnSpan * cellWidth + (slot.columnSpan - 1) * gap;
    final tileHeight = spansLastRow
        ? gridHeight - top
        : slot.rowSpan * cellHeight + (slot.rowSpan - 1) * gap;
    final isHero = slot.placement.span == ProfileGridSpan.double;

    return AnimatedPositioned(
      duration: _densityAnimationDuration,
      curve: Curves.easeInOut,
      left: left,
      top: top,
      width: tileWidth,
      height: tileHeight,
      child: ClipRRect(
        borderRadius: gap > 0
            ? BorderRadius.circular(ProfileFigmaTokens.contentGridRadius)
            : BorderRadius.zero,
        child: ProfileGridTile(
          thumbnailUrl: gridItem.thumbnailUrl,
          isVideo: gridItem.isVideo,
          showVrBadge: gridItem.showVrBadge,
          isHero: isHero,
          isRepost: gridItem.isRepost,
          gridTitle: gridItem.gridTitle,
          onTap: () => widget.onItemTap(gridItem.sourceIndex),
          onLongPress: widget.onItemLongPress != null
              ? () => widget.onItemLongPress!(gridItem.sourceIndex)
              : null,
        ),
      ),
    );
  }
}

ProfileGridSpanOverride profileGridSpanOverrideFromReel(
  Map<String, dynamic> reel,
) {
  final raw = ((reel['profileGridSpan'] as String?) ?? '').toLowerCase().trim();
  return switch (raw) {
    'double' || 'large' || 'hero' || 'big' => ProfileGridSpanOverride.double,
    'unit' || 'small' => ProfileGridSpanOverride.unit,
    'auto' || '' => ProfileGridSpanOverride.auto,
    _ => ProfileGridSpanOverride.auto,
  };
}

/// Firestore value for [profileGridSpan].
String profileGridSpanToFirestore(ProfileGridSpanOverride override) {
  return switch (override) {
    ProfileGridSpanOverride.double => 'double',
    ProfileGridSpanOverride.unit => 'unit',
    ProfileGridSpanOverride.auto => 'auto',
  };
}

List<ProfileGridItem> profileGridItemsFromReels({
  required List<Map<String, dynamic>> reels,
  required String Function(Map<String, dynamic> reel) thumbnailFor,
  bool showVrBadge = false,
}) {
  return List.generate(reels.length, (index) {
    final reel = reels[index];
    final mediaType = ProfileGridPosts.mediaType(reel);
    return ProfileGridItem(
      sourceIndex: index,
      thumbnailUrl: thumbnailFor(reel),
      views: (reel['views'] as num?)?.toInt() ?? 0,
      likes: (reel['likes'] as num?)?.toInt() ?? 0,
      shares: ReelEngagement.repostCount(reel),
      privacy: ReelCountPrivacy.fromMap(reel),
      isVideo: mediaType == 'video',
      showVrBadge: showVrBadge,
      isRepost: reel['isRepost'] == true,
      spanOverride: profileGridSpanOverrideFromReel(reel),
      gridTitle: ProfileGridTitle.fromReel(reel),
    );
  });
}
