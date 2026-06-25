import 'profile_grid_models.dart';

/// Assigns 1×1 / 2×2 spans for creator profile grids (source order preserved).
abstract final class ProfileGridLayoutEngine {
  ProfileGridLayoutEngine._();

  /// One 2×2 hero + masonry fill per 4×4 cell block (16 posts).
  static const int artistChunkSize = 16;

  static List<ProfileGridPlacement> layout({
    required int itemCount,
    required List<int> viewsByIndex,
    required ProfileGridLayoutMode mode,
    int minViewsForDouble = 0,
    List<ProfileGridSpanOverride> spanOverrideByIndex = const [],
  }) {
    if (itemCount <= 0) return const [];

    return List.generate(itemCount, (index) {
      return ProfileGridPlacement(
        sourceIndex: index,
        span: _spanForIndex(
          index: index,
          itemCount: itemCount,
          viewsByIndex: viewsByIndex,
          mode: mode,
          minViewsForDouble: minViewsForDouble,
          spanOverrideByIndex: spanOverrideByIndex,
        ),
      );
    });
  }

  static ProfileGridSpan _spanForIndex({
    required int index,
    required int itemCount,
    required List<int> viewsByIndex,
    required ProfileGridLayoutMode mode,
    required int minViewsForDouble,
    required List<ProfileGridSpanOverride> spanOverrideByIndex,
  }) {
    return switch (_overrideAt(index, spanOverrideByIndex)) {
      ProfileGridSpanOverride.double => ProfileGridSpan.double,
      ProfileGridSpanOverride.unit => ProfileGridSpan.unit,
      ProfileGridSpanOverride.auto => _autoSpan(
          index: index,
          itemCount: itemCount,
          viewsByIndex: viewsByIndex,
          mode: mode,
          minViewsForDouble: minViewsForDouble,
          spanOverrideByIndex: spanOverrideByIndex,
        ),
    };
  }

  static ProfileGridSpan _autoSpan({
    required int index,
    required int itemCount,
    required List<int> viewsByIndex,
    required ProfileGridLayoutMode mode,
    required int minViewsForDouble,
    required List<ProfileGridSpanOverride> spanOverrideByIndex,
  }) {
    switch (mode) {
      case ProfileGridLayoutMode.uniform:
        return ProfileGridSpan.unit;
      case ProfileGridLayoutMode.artistModern:
        final chunkStart = (index ~/ artistChunkSize) * artistChunkSize;
        final chunkEnd = chunkStart + artistChunkSize > itemCount
            ? itemCount
            : chunkStart + artistChunkSize;

        for (var i = chunkStart; i < chunkEnd; i++) {
          if (_overrideAt(i, spanOverrideByIndex) ==
              ProfileGridSpanOverride.double) {
            return ProfileGridSpan.unit;
          }
        }

        return index == chunkStart
            ? ProfileGridSpan.double
            : ProfileGridSpan.unit;
    }
  }

  static ProfileGridSpanOverride _overrideAt(
    int index,
    List<ProfileGridSpanOverride> spanOverrideByIndex,
  ) {
    if (index < 0 || index >= spanOverrideByIndex.length) {
      return ProfileGridSpanOverride.auto;
    }
    return spanOverrideByIndex[index];
  }
}
