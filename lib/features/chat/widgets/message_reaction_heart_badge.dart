import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_sizes.dart';
import '../utils/chat_constants.dart';

/// Figma like badge — 33×33 grey circle with pink heart, bottom-right of bubble.
class MessageReactionHeartBadge extends StatelessWidget {
  const MessageReactionHeartBadge({
    super.key,
    this.onTap,
    this.size,
  });

  final VoidCallback? onTap;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final badgeSize = size ?? AppSizes.chatMessageReactionHeart;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SvgPicture.asset(
        ChatAssets.messageReactionHeart,
        width: badgeSize,
        height: badgeSize,
      ),
    );
  }
}
