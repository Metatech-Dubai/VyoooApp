import 'package:flutter_test/flutter_test.dart';
import 'package:vyooo/core/widgets/profile/profile_grid_models.dart';
import 'package:vyooo/core/widgets/profile/profile_span_grid_layout.dart';

void main() {
  group('ProfileSpanGridLayout', () {
    test('packs hero at index 0 in four columns', () {
      final placements = List.generate(
        9,
        (i) => ProfileGridPlacement(
          sourceIndex: i,
          span: i == 0 ? ProfileGridSpan.double : ProfileGridSpan.unit,
        ),
      );
      final slots = ProfileSpanGridLayout.pack(
        placements: placements,
        crossAxisCount: 4,
      );
      expect(slots.length, 9);
      final hero = slots.where((s) => s.placement.sourceIndex == 0).single;
      expect(hero.row, 0);
      expect(hero.column, 0);
      expect(hero.columnSpan, 2);
      expect(hero.rowSpan, 2);
      final besideTop = slots.where((s) => s.placement.sourceIndex == 1).single;
      expect(besideTop.row, 0);
      expect(besideTop.column, 2);
    });

    test('packs double at index 3 without error', () {
      final placements = List.generate(
        6,
        (i) => ProfileGridPlacement(
          sourceIndex: i,
          span: i == 3 ? ProfileGridSpan.double : ProfileGridSpan.unit,
        ),
      );
      final slots = ProfileSpanGridLayout.pack(
        placements: placements,
        crossAxisCount: 3,
      );
      expect(slots.length, 6);
      final large = slots
          .where((s) => s.placement.sourceIndex == 3)
          .single;
      expect(large.columnSpan, 2);
      expect(large.rowSpan, 2);
    });

    test('coerces double spans to unit on single column', () {
      final placements = [
        const ProfileGridPlacement(
          sourceIndex: 0,
          span: ProfileGridSpan.double,
        ),
        const ProfileGridPlacement(
          sourceIndex: 1,
          span: ProfileGridSpan.unit,
        ),
      ];
      final slots = ProfileSpanGridLayout.pack(
        placements: placements,
        crossAxisCount: 1,
      );
      expect(slots.length, 2);
      expect(slots.every((s) => s.columnSpan == 1 && s.rowSpan == 1), isTrue);
    });

    test('packs multiple doubles in three columns', () {
      final placements = [
        const ProfileGridPlacement(
          sourceIndex: 0,
          span: ProfileGridSpan.double,
        ),
        const ProfileGridPlacement(
          sourceIndex: 1,
          span: ProfileGridSpan.unit,
        ),
        const ProfileGridPlacement(
          sourceIndex: 2,
          span: ProfileGridSpan.unit,
        ),
        const ProfileGridPlacement(
          sourceIndex: 3,
          span: ProfileGridSpan.double,
        ),
      ];
      expect(
        () => ProfileSpanGridLayout.pack(
          placements: placements,
          crossAxisCount: 3,
        ),
        returnsNormally,
      );
    });
  });
}
