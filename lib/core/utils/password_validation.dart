/// Password validation rules. Kept separate from UI.
class PasswordValidation {
  PasswordValidation._();

  static const int minLength = 8;
  static final RegExp _specialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;/`~]');

  static bool hasMinLength(String value) => value.length >= minLength;
  static bool hasSpecialCharacter(String value) => _specialChar.hasMatch(value);

  static bool isStrong(String value) =>
      hasMinLength(value) && hasSpecialCharacter(value);
}
