import 'package:flutter/material.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_light_surface.dart';
import '../../core/widgets/settings/settings_inner_app_bar.dart';
import 'privacy_policy_screen.dart';
import 'terms_service_screen.dart';
import 'package:vyooo/core/widgets/app_gradient_background.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAppBar(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppLightSurface.cardFill,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppLightSurface.border,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          _AboutTile(
                            label: AppStrings.privacyPolicy,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const PrivacyPolicyScreen(),
                                ),
                              );
                            },
                          ),
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: AppLightSurface.divider,
                          ),
                          _AboutTile(
                            label: AppStrings.termsOfService,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const TermsServiceScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return const SettingsInnerAppBar(title: 'About');
  }
}

class _AboutTile extends StatelessWidget {
  const _AboutTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppLightSurface.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppLightSurface.chevron,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
