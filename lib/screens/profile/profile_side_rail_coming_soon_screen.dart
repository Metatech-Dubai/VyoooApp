import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';
import 'profile_figma_tokens.dart';

/// Minimal full-screen placeholder for profile side-rail destinations.
class ProfileSideRailComingSoonScreen extends StatelessWidget {
  const ProfileSideRailComingSoonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProfileFigmaTokens.screenBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: ProfileFigmaTokens.primaryText,
                  size: 20,
                ),
              ),
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'Coming Soon',
                  textAlign: TextAlign.center,
                  style: AppTypography.profileDisplayName,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
