import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Compact quoted-message strip shown inside a chat bubble.
class MessageReplyQuote extends StatelessWidget {
  const MessageReplyQuote({
    super.key,
    required this.senderName,
    required this.preview,
    required this.isSentBubble,
  });

  final String senderName;
  final String preview;
  final bool isSentBubble;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: isSentBubble ? 0.15 : 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isSentBubble ? Colors.white70 : AppColors.brandMagenta,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            senderName,
            style: TextStyle(
              color: isSentBubble ? Colors.white : AppColors.brandMagenta,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            preview,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
