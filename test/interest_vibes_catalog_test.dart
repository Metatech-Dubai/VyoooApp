import 'package:flutter_test/flutter_test.dart';
import 'package:vyooo/core/onboarding/interest_vibes_catalog.dart';

void main() {
  test('catalog has 200+ unique vibes', () {
    expect(InterestVibesCatalog.count, greaterThanOrEqualTo(200));
    expect(InterestVibesCatalog.all.toSet().length, InterestVibesCatalog.count);
  });

  test('rowsFor distributes round-robin across rows', () {
    final rows = InterestVibesCatalog.rowsFor(
      ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
      rowCount: 3,
    );
    expect(rows, [
      ['a', 'd', 'g'],
      ['b', 'e'],
      ['c', 'f'],
    ]);
  });
}
