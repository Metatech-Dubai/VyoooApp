import 'package:flutter/material.dart';

import '../theme/app_background_assets.dart';
import '../theme/app_gradients.dart';

/// Background for [PostFeedScreen] (`assets/bgImages/2.png`).
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
        return const DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppGradients.feedGradient,
          ),
        );
      },
    );
  }
}
