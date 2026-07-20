import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_background_assets.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../core/widgets/settings/settings_inner_app_bar.dart';
import 'chat_support_screen.dart';
import '../../core/theme/app_light_surface.dart';

class ContactSupportScreen extends StatelessWidget {
  const ContactSupportScreen({super.key});

  static const String _supportPhoneDisplay = '(021) 88888889';
  static const String _supportPhoneDial = '+622188888889';
  static const String _supportEmail = 'support@vyooo.com';

  Future<void> _launchUri(BuildContext context, Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {
      // Fall through to snackbar.
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open. Please try again.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _launchPhone(BuildContext context) {
    _launchUri(context, Uri.parse('tel:$_supportPhoneDial'));
  }

  void _launchEmail(BuildContext context) {
    _launchUri(context, Uri.parse('mailto:$_supportEmail'));
  }

  Widget _buildSupportContactText(BuildContext context) {
    const baseStyle = TextStyle(
      color: AppLightSurface.primaryText,
      fontSize: 16,
      height: 1.6,
    );
    final linkStyle = baseStyle.copyWith(
      color: AppLightSurface.primaryText,
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w600,
    );

    return Text.rich(
      textAlign: TextAlign.center,
      TextSpan(
        style: baseStyle.copyWith(color: AppLightSurface.secondaryText),
        children: [
          const TextSpan(text: 'We’re here to help. Call '),
          TextSpan(
            text: _supportPhoneDisplay,
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => _launchPhone(context),
          ),
          const TextSpan(text: ' or\nemail '),
          TextSpan(
            text: _supportEmail,
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => _launchEmail(context),
          ),
          const TextSpan(text: ' anytime.'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        backgroundAsset: AppBackgroundAssets.contactSupport,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAppBar(context),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(flex: 2),
                Center(
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: AppLightSurface.primaryText,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppLightSurface.border, width: 1.5),
                    ),
                    child: const Center(
                      child: Text(
                        '?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 80,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                const Text(
                  'How can we help\nyou today?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
              color: AppLightSurface.primaryText,
                    fontSize: 42,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 32),
                _buildSupportContactText(context),
                const Spacer(flex: 3),
                // Start Chat input placeholder/button
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const ChatSupportScreen()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: AppLightSurface.cardFill,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppLightSurface.cardFill),
                    ),
                    child: const Text(
                      'Start Chat..',
                      style: TextStyle(
                        color: AppLightSurface.mutedText,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                    const SizedBox(height: AppSpacing.xl),
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

  Widget _buildAppBar(BuildContext context) {
    return const SettingsInnerAppBar(title: 'Contact Support');
  }
}
