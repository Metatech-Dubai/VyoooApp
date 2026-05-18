import 'package:flutter/material.dart';

import '../../core/theme/app_padding.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../core/widgets/auth/auth_widgets.dart';
import 'reset_password_screen.dart';

/// OTP step for password reset — navigates to [ResetPasswordScreen] after verify.
class ResetPasswordOTPScreen extends StatelessWidget {
  const ResetPasswordOTPScreen({
    super.key,
    this.emailOrUsername,
    this.oobCode,
  });

  final String? emailOrUsername;
  final String? oobCode;

  void _onOtpVerified(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResetPasswordScreen(
          emailOrUsername: emailOrUsername,
          oobCode: oobCode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType.auth,
        child: SingleChildScrollView(
          padding: AppPadding.authFormHorizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.sm),
              const AuthScreenHeader(title: 'Reset Password'),
              if (emailOrUsername != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'OTP sent to $emailOrUsername',
                  style: AppTypography.authSmallBody,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              AuthPrimaryButton(
                label: 'Verify & Continue',
                onPressed: () => _onOtpVerified(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
