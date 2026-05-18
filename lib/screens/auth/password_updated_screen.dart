import 'package:flutter/material.dart';

import '../../core/theme/app_padding.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../core/widgets/auth/auth_widgets.dart';
import '../../core/widgets/vyooo_brand_logo.dart';
import 'sign_in_screen.dart';

class PasswordUpdatedScreen extends StatelessWidget {
  const PasswordUpdatedScreen({super.key});

  void _onGoToLogin(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType.auth,
        child: Padding(
          padding: AppPadding.authFormHorizontal,
          child: Column(
            children: [
              const Spacer(),
              const VyoooBrandLogo(size: AppSizes.authLogoHeight),
              const SizedBox(height: AppSpacing.xxl),
              const Text(
                'Password Updated',
                style: AppTypography.authHeadline,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              _buildIllustration(),
              const SizedBox(height: AppSpacing.xxl),
              AuthPrimaryButton(
                label: 'Go to Login',
                onPressed: () => _onGoToLogin(context),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIllustration() {
    return Center(
      child: Image.asset(
        'assets/images/illustration.png',
        height: 230,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const SizedBox(
          height: 230,
          child: Center(
            child: Icon(
              Icons.check_circle_outline,
              size: 120,
              color: AppTheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
