import 'package:flutter/material.dart';

import '../../../core/theme/app_sizes.dart';
import '../utils/reaction_helpers.dart';
import 'message_reaction_heart_badge.dart';

/// Positions the Figma heart badge on the bottom-right corner of a message bubble.
class MessageReactionHeartOverlay extends StatelessWidget {
  const MessageReactionHeartOverlay({
    super.key,
    required this.child,
    required this.reactions,
    this.onHeartTap,
  });

  final Widget child;
  final Map<String, dynamic> reactions;
  final VoidCallback? onHeartTap;

  @override
  Widget build(BuildContext context) {
    if (!hasHeartReaction(reactions)) return child;

    final overlap = AppSizes.chatMessageReactionHeartOverlap;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: overlap),
          child: child,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: MessageReactionHeartBadge(onTap: onHeartTap),
        ),
      ],
    );
  }
}
