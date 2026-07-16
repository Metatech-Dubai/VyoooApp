import 'package:flutter/material.dart';

import '../theme/app_background_assets.dart';
import '../theme/app_light_surface.dart';

/// Background for [PostFeedScreen] — white fallback when asset missing.
class PostFeedScreenBackground extends StatelessWidget {
  const PostFeedScreenBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppBackgroundAssets.postFeed,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return const ColoredBox(color: AppLightSurface.background);
      },
    );
  }
}
