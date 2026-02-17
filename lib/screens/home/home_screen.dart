import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_padding.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/wrappers/auth_wrapper.dart';
import '../../core/wrappers/main_nav_wrapper.dart';
import '../../core/widgets/app_gradient_background.dart';

/// Main home after onboarding. Replace with your actual home content.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _goToReels(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavWrapper()),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        type: GradientType.profile,
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: AppPadding.card,
                  child: TextButton.icon(
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout, color: Colors.white70, size: 20),
                    label: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Welcome to Vyooo',
                        style: TextStyle(
                          color: AppTheme.defaultTextColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      AppPadding.sectionGap,
                      ElevatedButton(
                        onPressed: () => _goToReels(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: AppPadding.screenHorizontal.copyWith(left: 32, right: 32, top: AppSpacing.md, bottom: AppSpacing.md),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.buttonRadius,
                          ),
                        ),
                        child: const Text(
                          'Go to Reels',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
