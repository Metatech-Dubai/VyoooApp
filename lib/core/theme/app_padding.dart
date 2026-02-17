import 'package:flutter/widgets.dart';

/// Centralized padding and gap widgets. Use with AppSpacing for numbers.
class AppPadding {
  static const screenHorizontal =
      EdgeInsets.symmetric(horizontal: 16);

  static const screenVertical =
      EdgeInsets.symmetric(vertical: 16);

  static const card =
      EdgeInsets.all(16);

  static const input =
      EdgeInsets.symmetric(horizontal: 16, vertical: 14);

  static const button =
      EdgeInsets.symmetric(vertical: 14);

  static const sectionGap =
      SizedBox(height: 24);

  static const itemGap =
      SizedBox(height: 16);

  /// Auth/onboarding form (wider horizontal)
  static const authFormHorizontal =
      EdgeInsets.symmetric(horizontal: 28);
}
