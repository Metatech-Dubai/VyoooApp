import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_gradient_background.dart';
import 'reset_password_screen.dart';

/// OTP verification for reset password. After successful verification, navigates to ResetPasswordScreen.
/// When opening from Firebase reset email link, pass [oobCode] so ResetPasswordScreen can confirm the reset.
class ResetPasswordOTPScreen extends StatelessWidget {
  const ResetPasswordOTPScreen({
    super.key,
    this.emailOrUsername,
    this.oobCode,
  });

  final String? emailOrUsername;

  /// Code from Firebase password reset email link. Pass through to ResetPasswordScreen.
  final String? oobCode;

  void _onOtpVerified(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ResetPasswordScreen(
          emailOrUsername: emailOrUsername,
          oobCode: oobCode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        type: GradientType.auth,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Reset Password',
                    style: TextStyle(
                      color: AppTheme.defaultTextColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (emailOrUsername != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'OTP sent to $emailOrUsername',
                      style: const TextStyle(
                        color: AppTheme.secondaryTextColor,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => _onOtpVerified(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.buttonBackground,
                        foregroundColor: AppTheme.buttonTextColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Verify & Continue',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
