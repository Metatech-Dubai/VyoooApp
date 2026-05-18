import 'package:flutter/material.dart';

import 'auth_password_visibility_button.dart';
import 'auth_underline_text_field.dart';

/// Underline password field with built-in visibility toggle.
class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    super.key,
    required this.controller,
    this.hint = 'Password',
    this.focusNode,
    this.initiallyObscured = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final bool initiallyObscured;
  final ValueChanged<String>? onChanged;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.initiallyObscured;
  }

  @override
  Widget build(BuildContext context) {
    return AuthUnderlineTextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      onChanged: widget.onChanged,
      icon: Icons.lock_outline,
      hint: widget.hint,
      obscureText: _obscured,
      suffixIcon: AuthPasswordVisibilityButton(
        obscured: _obscured,
        onToggle: () => setState(() => _obscured = !_obscured),
      ),
    );
  }
}
