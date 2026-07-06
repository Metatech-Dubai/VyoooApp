import 'package:flutter_test/flutter_test.dart';
import 'package:vyooo/services/reserved_usernames.dart';
import 'package:vyooo/services/username_validation.dart';

void main() {
  group('UsernameValidation', () {
    test('normalize preserves case and strips whitespace', () {
      expect(UsernameValidation.normalize('  My_Name  '), 'My_Name');
    });

    test('isValidFormat allows mixed case', () {
      expect(UsernameValidation.isValidFormat('AbCd'), isTrue);
      expect(UsernameValidation.isValidFormat('User_One'), isTrue);
    });

    test('isValidFormat rejects too short', () {
      expect(UsernameValidation.isValidFormat('Ab'), isFalse);
      expect(UsernameValidation.isValidFormat('Abc'), isFalse);
    });

    test('isValidFormat rejects three-letter usernames', () {
      expect(UsernameValidation.isValidFormat('dev'), isFalse);
    });
  });

  group('ReservedUsernames', () {
    test('reserves platform terms', () {
      expect(ReservedUsernames.isReserved('admin'), isTrue);
      expect(ReservedUsernames.isReserved('Vyooo'), isTrue);
    });

    test('reserves country government namespaces', () {
      expect(ReservedUsernames.isReserved('afghanistan_government'), isTrue);
      expect(ReservedUsernames.isReserved('albania'), isTrue);
    });

    test('allows normal usernames', () {
      expect(ReservedUsernames.isReserved('johnsmith'), isFalse);
      expect(ReservedUsernames.isReserved('my_creator_page'), isFalse);
    });
  });
}
