import 'package:flutter_test/flutter_test.dart';
import 'package:vyooo/core/widgets/profile/profile_grid_layout_engine.dart';
import 'package:vyooo/core/widgets/profile/profile_grid_models.dart';

void main() {
  group('ProfileGridLayoutEngine', () {
    test('uniform mode returns one unit tile per item', () {
      final placements = ProfileGridLayoutEngine.layout(
        itemCount: 5,
        viewsByIndex: [10, 20, 30, 40, 50],
        mode: ProfileGridLayoutMode.uniform,
      );
      expect(placements.length, 5);
      expect(
        placements.every((p) => p.span == ProfileGridSpan.unit),
        isTrue,
      );
      expect(placements.map((p) => p.sourceIndex).toList(), [0, 1, 2, 3, 4]);
    });

    test('artistModern promotes first post in each chunk to 2×2', () {
      final views = List<int>.generate(16, (i) => i);
      views[15] = 1000;
      final placements = ProfileGridLayoutEngine.layout(
        itemCount: 16,
        viewsByIndex: views,
        mode: ProfileGridLayoutMode.artistModern,
      );
      expect(placements.length, 16);
      expect(placements[0].span, ProfileGridSpan.double);
      expect(placements[15].span, ProfileGridSpan.unit);
      expect(
        placements.where((p) => p.span == ProfileGridSpan.double).length,
        1,
      );
    });

    test('manual double stays at post index in grid order', () {
      final views = List<int>.generate(16, (i) => i + 1);
      final overrides = List<ProfileGridSpanOverride>.filled(
        16,
        ProfileGridSpanOverride.auto,
      );
      overrides[3] = ProfileGridSpanOverride.double;
      final placements = ProfileGridLayoutEngine.layout(
        itemCount: 16,
        viewsByIndex: views,
        mode: ProfileGridLayoutMode.artistModern,
        spanOverrideByIndex: overrides,
      );
      expect(placements[3].sourceIndex, 3);
      expect(placements[3].span, ProfileGridSpan.double);
      expect(
        placements.where((p) => p.span == ProfileGridSpan.double).length,
        1,
      );
    });

    test('manual unit prevents auto double on that post', () {
      final views = List<int>.generate(16, (i) => i + 1);
      final overrides = List<ProfileGridSpanOverride>.filled(
        16,
        ProfileGridSpanOverride.auto,
      );
      overrides[0] = ProfileGridSpanOverride.unit;
      final placements = ProfileGridLayoutEngine.layout(
        itemCount: 16,
        viewsByIndex: views,
        mode: ProfileGridLayoutMode.artistModern,
        spanOverrideByIndex: overrides,
      );
      expect(placements[0].span, ProfileGridSpan.unit);
      expect(
        placements.any((p) => p.span == ProfileGridSpan.double),
        isFalse,
      );
    });

    test('uniform honors manual double', () {
      final overrides = [
        ProfileGridSpanOverride.unit,
        ProfileGridSpanOverride.double,
      ];
      final placements = ProfileGridLayoutEngine.layout(
        itemCount: 2,
        viewsByIndex: [0, 100],
        mode: ProfileGridLayoutMode.uniform,
        spanOverrideByIndex: overrides,
      );
      expect(placements[0].span, ProfileGridSpan.unit);
      expect(placements[1].span, ProfileGridSpan.double);
    });
  });
}
