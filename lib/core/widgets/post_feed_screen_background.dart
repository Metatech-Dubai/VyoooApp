import 'package:flutter/material.dart';

import '../theme/app_light_surface.dart';

/// Background for [PostFeedScreen] — light surface (profile grid → posts list).
class PostFeedScreenBackground extends StatelessWidget {
  const PostFeedScreenBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: AppLightSurface.background);
  }
}
