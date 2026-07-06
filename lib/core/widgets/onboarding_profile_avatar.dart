import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_sizes.dart';

/// Decorative profile avatar on light onboarding steps (Figma 162×162).
class OnboardingProfileAvatar extends StatelessWidget {
  const OnboardingProfileAvatar({super.key});

  static const String assetPath =
      'assets/vyooO_icons/Onboarding/username_profile_avatar.svg';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetPath,
      width: AppSizes.onboardingProfileAvatarSize,
      height: AppSizes.onboardingProfileAvatarSize,
    );
  }
}
