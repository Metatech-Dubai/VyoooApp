import 'package:flutter_test/flutter_test.dart';
import 'package:vyooo/core/widgets/profile/profile_grid_title.dart';

void main() {
  group('ProfileGridTitle', () {
    test('fromReel clamps long values', () {
      final reel = {'profileGridTitle': 'abcdefghijklmnop'};
      expect(
        ProfileGridTitle.fromReel(reel),
        'abcdefghijklmno',
      );
    });

    test('normalizeForSave trims and clamps', () {
      expect(
        ProfileGridTitle.normalizeForSave('  hello world extra  '),
        'hello world ext',
      );
      expect(ProfileGridTitle.normalizeForSave('   '), '');
    });
  });
}
