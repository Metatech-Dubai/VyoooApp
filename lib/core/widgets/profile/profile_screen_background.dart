import 'package:flutter/material.dart';

import '../../../screens/profile/profile_figma_tokens.dart';

/// Full-screen profile background — solid white for the redesigned profile.
class ProfileScreenBackground extends StatelessWidget {
  const ProfileScreenBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: ProfileFigmaTokens.screenBackground);
  }
}
