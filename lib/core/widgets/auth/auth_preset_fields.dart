import 'package:flutter/material.dart';

import '../../theme/app_padding.dart';
import 'auth_underline_text_field.dart';

export 'auth_password_field.dart' show AuthPasswordField;
export 'auth_phone_field.dart' show AuthPhoneField;

/// Reusable auth form fields — register, sign-in, onboarding, etc.
///
/// ```dart
/// AuthFieldColumn(
///   children: [
///     AuthNameField(controller: _nameController),
///     AuthEmailField(controller: _emailController),
///     AuthPasswordField(controller: _passwordController),
///   ],
/// )
/// ```

class AuthNameField extends StatelessWidget {
  const AuthNameField({super.key, required this.controller, this.focusNode});

  final TextEditingController controller;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return AuthUnderlineTextField(
      controller: controller,
      focusNode: focusNode,
      icon: Icons.person_outline,
      hint: 'Name',
      keyboardType: TextInputType.name,
      textCapitalization: TextCapitalization.words,
    );
  }
}

/// Single full-name field for light-theme sign-up (Figma).
class AuthFullNameField extends StatelessWidget {
  const AuthFullNameField({super.key, required this.controller, this.focusNode});

  final TextEditingController controller;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return AuthUnderlineTextField(
      controller: controller,
      focusNode: focusNode,
      icon: Icons.person_outline,
      hint: 'Full Name',
      keyboardType: TextInputType.name,
      textCapitalization: TextCapitalization.words,
    );
  }
}

class AuthSurnameField extends StatelessWidget {
  const AuthSurnameField({super.key, required this.controller, this.focusNode});

  final TextEditingController controller;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return AuthUnderlineTextField(
      controller: controller,
      focusNode: focusNode,
      icon: Icons.person_outline,
      hint: 'Surname',
      keyboardType: TextInputType.name,
      textCapitalization: TextCapitalization.words,
    );
  }
}

class AuthEmailField extends StatelessWidget {
  const AuthEmailField({super.key, required this.controller, this.focusNode});

  final TextEditingController controller;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return AuthUnderlineTextField(
      controller: controller,
      focusNode: focusNode,
      icon: Icons.mail_outline,
      hint: 'Email',
      keyboardType: TextInputType.emailAddress,
    );
  }
}

/// Email, username, or display name — sign-in identifier field.
class AuthLoginIdentifierField extends StatelessWidget {
  const AuthLoginIdentifierField({
    super.key,
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.hint = 'Email, Username or Name',
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return AuthUnderlineTextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      icon: Icons.mail_outline,
      hint: hint,
      keyboardType: TextInputType.emailAddress,
    );
  }
}

class AuthUsernameField extends StatelessWidget {
  const AuthUsernameField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hint = 'Username',
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return AuthUnderlineTextField(
      controller: controller,
      focusNode: focusNode,
      icon: Icons.alternate_email_outlined,
      hint: hint,
      keyboardType: TextInputType.text,
    );
  }
}

/// Standard vertical spacing between auth fields.
class AuthFieldColumn extends StatelessWidget {
  const AuthFieldColumn({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      spaced.add(children[i]);
      if (i < children.length - 1) {
        spaced.add(AppPadding.authFieldGap);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: spaced,
    );
  }
}
