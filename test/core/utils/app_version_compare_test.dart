import 'package:flutter_test/flutter_test.dart';
import 'package:vyooo/core/utils/app_version_compare.dart';

void main() {
  group('AppVersionCompare', () {
    test('orders semantic versions correctly', () {
      expect(AppVersionCompare.isOlderThan('1.1.9', '1.2.0'), isTrue);
      expect(AppVersionCompare.isOlderThan('1.2.0', '1.1.9'), isFalse);
      expect(AppVersionCompare.isOlderThan('1.9.0', '1.10.0'), isTrue);
      expect(AppVersionCompare.isOlderThan('1.1.9', '1.1.9'), isFalse);
    });

    test('ignores build suffix after plus', () {
      expect(AppVersionCompare.isOlderThan('1.1.9+33', '1.2.0'), isTrue);
    });
  });
}
