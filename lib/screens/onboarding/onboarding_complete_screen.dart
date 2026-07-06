import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_links.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_padding.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/auth/auth_widgets.dart';
import '../../core/widgets/vyooo_brand_logo.dart';
import '../../core/widgets/onboarding_progress_bar.dart';
import '../../services/onboarding_storage.dart';
import '../../core/wrappers/main_nav_wrapper.dart';

class OnboardingCompleteScreen extends StatelessWidget {
  const OnboardingCompleteScreen({super.key});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _onAccept(BuildContext context) async {
    final uid = AuthService().currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      try {
        await UserService().updateUserProfile(
          uid: uid,
          onboardingCompleted: true,
        );
      } catch (_) {
        // Still complete onboarding and go to Home so user isn't stuck
        await OnboardingStorage.setComplete(true);
        if (!context.mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainNavWrapper()),
          (route) => false,
        );
        return;
      }
    }
    await OnboardingStorage.setComplete(true);
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MainNavWrapper()),
      (route) => false,
    );
  }

  Future<void> _onDecline(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.lightScaffoldBackground,
        title: Text(
          'Exit onboarding?',
          style: AppTypography.authDialogTitle.copyWith(
            color: AppTheme.lightOnSurface,
          ),
        ),
        content: Text(
          'Are you sure you want to exit onboarding?',
          style: AppTypography.authSmallBody.copyWith(
            color: AppTheme.lightMutedBody,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTypography.authSmallBody.copyWith(
                color: AppTheme.lightMutedBody,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Exit',
              style: AppTypography.authAccentLink,
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLightScaffold(
      scrollable: false,
      padding: AppPadding.authFormHorizontal,
      stackChildren: [
        AuthFloatingBackButton(onPressed: () => _onBack(context)),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: AppSpacing.xl - AppSpacing.xs),
          const VyoooBrandLogo.auth(),
          AppPadding.itemGap,
          const OnboardingProgressBar(progress: 1.0),
          SizedBox(height: AppSpacing.xl + AppSpacing.md),
          Text(
            "You're all set!",
            style: AppTypography.authHeadline.copyWith(
              color: AppTheme.lightOnSurface,
            ),
          ),
          SizedBox(height: AppSpacing.xl - AppSpacing.xs),
          _buildDescription(context),
          const Spacer(),
          AuthPrimaryButton(
            label: 'I Accept',
            onPressed: () => _onAccept(context),
          ),
          AppPadding.itemGap,
          _buildDeclineButton(context),
          SizedBox(height: AppSpacing.xl - AppSpacing.xs),
        ],
      ),
    );
  }

  Widget _buildDescription(BuildContext context) {
    const baseStyle = TextStyle(
      fontSize: 14,
      color: AppTheme.lightMutedBody,
      height: 1.5,
      fontWeight: FontWeight.w400,
    );
    const linkStyle = TextStyle(
      fontSize: 14,
      color: AppTypography.authAccentLinkColor,
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(
            text:
                "Tap Agree & Continue to start your VyooO experience.\nBy continuing, you confirm that you've read and accepted our ",
          ),
          TextSpan(
            text: 'Terms of Use',
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => _openUrl(AppLinks.termsOfUse),
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => _openUrl(AppLinks.privacyPolicy),
          ),
          const TextSpan(
            text: '.\nPlease review the links above for more details.',
          ),
        ],
      ),
    );
  }

  Widget _buildDeclineButton(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => _onDecline(context),
        child: Text(
          'Decline',
          style: AppTypography.authSmallBody.copyWith(
            color: AppTheme.lightMutedBody,
          ),
        ),
      ),
    );
  }

  Future<void> _onBack(BuildContext context) async {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    await AuthService().signOut();
  }
}
