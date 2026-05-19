import 'package:flutter_test/flutter_test.dart';
import 'package:vyooo/core/utils/establishment_date_validation.dart';

void main() {
  test('rejects future establishment date', () {
    final future = DateTime.now().add(const Duration(days: 1));
    expect(
      EstablishmentDateValidation.isValidEstablishmentDate(future),
      isFalse,
    );
  });

  test('accepts past establishment date', () {
    expect(
      EstablishmentDateValidation.isValidEstablishmentDateString('2001-06-15'),
      isTrue,
    );
  });
}
