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

    test('artistModern promotes highest views in chunk at same index', () {
      final views = List<int>.generate(12, (i) => i);
      views[11] = 1000;
      final placements = ProfileGridLayoutEngine.layout(
        itemCount: 12,
        viewsByIndex: views,
        mode: ProfileGridLayoutMode.artistModern,
      );
      expect(placements.length, 12);
      expect(placements[11].span, ProfileGridSpan.double);
      expect(
        placements.where((p) => p.span == ProfileGridSpan.double).length,
        1,
      );
    });

    test('manual double stays at post index in grid order', () {
      final views = List<int>.generate(12, (i) => i + 1);
      final overrides = List<ProfileGridSpanOverride>.filled(
        12,
        ProfileGridSpanOverride.auto,
      );
      overrides[3] = ProfileGridSpanOverride.double;
      final placements = ProfileGridLayoutEngine.layout(
        itemCount: 12,
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
      final views = List<int>.generate(12, (i) => i + 1);
      final overrides = List<ProfileGridSpanOverride>.filled(
        12,
        ProfileGridSpanOverride.auto,
      );
      overrides[11] = ProfileGridSpanOverride.unit;
      final placements = ProfileGridLayoutEngine.layout(
        itemCount: 12,
        viewsByIndex: views,
        mode: ProfileGridLayoutMode.artistModern,
        spanOverrideByIndex: overrides,
      );
      expect(placements[11].span, ProfileGridSpan.unit);
      expect(
        placements.any((p) => p.span == ProfileGridSpan.double),
        isTrue,
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
