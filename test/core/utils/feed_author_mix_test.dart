import 'package:flutter_test/flutter_test.dart';
import 'package:vyooo/core/utils/feed_author_mix.dart';

void main() {
  group('FeedAuthorMix.interleave', () {
    test('alternates accounts while keeping each account in input order', () {
      final mixed = FeedAuthorMix.interleave([
        {'id': 'a1', 'userId': 'A'},
        {'id': 'a2', 'userId': 'A'},
        {'id': 'a3', 'userId': 'A'},
        {'id': 'b1', 'userId': 'B'},
      ]);

      expect(
        mixed.map((reel) => reel['id']).toList(),
        ['a1', 'b1', 'a2', 'a3'],
      );
    });

    test('stops at the requested length', () {
      final mixed = FeedAuthorMix.interleave(
        [
          {'id': 'a1', 'userId': 'A'},
          {'id': 'a2', 'userId': 'A'},
          {'id': 'b1', 'userId': 'B'},
          {'id': 'b2', 'userId': 'B'},
        ],
        limit: 3,
      );

      expect(
        mixed.map((reel) => reel['id']).toList(),
        ['a1', 'b1', 'a2'],
      );
    });

    test('leaves a single account in its original order', () {
      final mixed = FeedAuthorMix.interleave([
        {'id': 'a1', 'userId': 'A'},
        {'id': 'a2', 'userId': 'A'},
      ]);

      expect(
        mixed.map((reel) => reel['id']).toList(),
        ['a1', 'a2'],
      );
    });
  });
}
