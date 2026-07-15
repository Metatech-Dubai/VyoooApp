import 'profile_grid_models.dart';

/// Slot for one post in a fixed-column span grid (supports 1×1 and 2×2).
class ProfileSpanGridSlot {
  const ProfileSpanGridSlot({
    required this.placement,
    required this.row,
    required this.column,
    required this.rowSpan,
    required this.columnSpan,
  });

  final ProfileGridPlacement placement;
  final int row;
  final int column;
  final int rowSpan;
  final int columnSpan;
}

/// Packs [placements] in source order into a [crossAxisCount]-wide grid.
abstract final class ProfileSpanGridLayout {
  ProfileSpanGridLayout._();

  /// 2×2 heroes need at least two columns; single-column grids use 1×1 only.
  static ProfileGridSpan effectiveSpan(
    ProfileGridSpan span,
    int crossAxisCount,
  ) {
    if (span == ProfileGridSpan.double && crossAxisCount < 2) {
      return ProfileGridSpan.unit;
    }
    return span;
  }

  static List<ProfileGridPlacement> coercePlacements(
    List<ProfileGridPlacement> placements,
    int crossAxisCount,
  ) {
    return [
      for (final placement in placements)
        ProfileGridPlacement(
          sourceIndex: placement.sourceIndex,
          span: effectiveSpan(placement.span, crossAxisCount),
        ),
    ];
  }

  static List<ProfileSpanGridSlot> pack({
    required List<ProfileGridPlacement> placements,
    required int crossAxisCount,
  }) {
    if (placements.isEmpty || crossAxisCount <= 0) return const [];

    final columnHeights = List<int>.filled(crossAxisCount, 0);
    final slots = <ProfileSpanGridSlot>[];

    for (final placement in coercePlacements(placements, crossAxisCount)) {
      final span =
          effectiveSpan(placement.span, crossAxisCount) ==
              ProfileGridSpan.double
          ? 2
          : 1;
      final position = _findPosition(
        columnHeights: columnHeights,
        crossAxisCount: crossAxisCount,
        rowSpan: span,
        columnSpan: span,
      );
      if (position == null) continue;

      final (row, column) = position;
      slots.add(
        ProfileSpanGridSlot(
          placement: placement,
          row: row,
          column: column,
          rowSpan: span,
          columnSpan: span,
        ),
      );
      _occupy(
        columnHeights: columnHeights,
        row: row,
        column: column,
        rowSpan: span,
        columnSpan: span,
      );
    }

    return slots;
  }

  static (int row, int column)? _findPosition({
    required List<int> columnHeights,
    required int crossAxisCount,
    required int rowSpan,
    required int columnSpan,
  }) {
    if (columnSpan > crossAxisCount) return null;

    var candidateRow = 0;
    while (true) {
      for (var column = 0; column <= crossAxisCount - columnSpan; column++) {
        if (_fits(
          columnHeights: columnHeights,
          row: candidateRow,
          column: column,
          rowSpan: rowSpan,
          columnSpan: columnSpan,
        )) {
          return (candidateRow, column);
        }
      }
      candidateRow++;
      if (candidateRow > 10000) return null;
    }
  }

  static bool _fits({
    required List<int> columnHeights,
    required int row,
    required int column,
    required int rowSpan,
    required int columnSpan,
  }) {
    for (var c = column; c < column + columnSpan; c++) {
      if (columnHeights[c] > row) return false;
    }
    return true;
  }

  static void _occupy({
    required List<int> columnHeights,
    required int row,
    required int column,
    required int rowSpan,
    required int columnSpan,
  }) {
    final bottom = row + rowSpan;
    for (var c = column; c < column + columnSpan; c++) {
      columnHeights[c] = bottom;
    }
  }

  static int rowCount(List<ProfileSpanGridSlot> slots) {
    if (slots.isEmpty) return 0;
    var max = 0;
    for (final slot in slots) {
      final end = slot.row + slot.rowSpan;
      if (end > max) max = end;
    }
    return max;
  }
}
