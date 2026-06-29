import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_padding.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/auth/auth_widgets.dart';
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
    return AuthLightScaffold(
      padding: AppPadding.authFormHorizontal,
      scrollable: false,
      body: Column(
        children: [
          const Spacer(),
          const AuthScreenHeader(
            centerAlign: true,
            title: 'Password\nUpdated',
          ),
          const SizedBox(height: AppSpacing.xxl),
          _buildIllustration(),
          const Spacer(),
          AuthPrimaryButton(
            label: 'Go to Login',
            onPressed: () => _onGoToLogin(context),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildIllustration() {
    return Center(
      child: Image.asset(
        'assets/images/illustration.png',
        height: 230,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Container(
          width: 160,
          height: 160,
          decoration: const BoxDecoration(
            color: AppColors.authBrandBurgundy,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check,
            size: 72,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
