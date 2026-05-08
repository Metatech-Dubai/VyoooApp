import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../models/chat_summary_model.dart';
import '../utils/chat_helpers.dart';

class ChatTile extends StatelessWidget {
  const ChatTile({
    super.key,
    required this.summary,
    required this.onTap,
  });

  final ChatSummaryModel summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = summary.avatarUrl.trim().isNotEmpty;
    final hasUnread = summary.unreadCount > 0;

    return InkWell(
      onTap: onTap,
      splashColor: AppColors.brandDeepMagenta.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasUnread
                    ? const LinearGradient(
                        colors: [Color(0xFFDE106B), Color(0xFF6B21A8)],
                      )
                    : null,
                color: hasUnread ? null : const Color(0xFF2A1B2E),
              ),
              padding: EdgeInsets.all(hasUnread ? 2 : 0),
              child: CircleAvatar(
                radius: hasUnread ? 22 : 24,
                backgroundColor: const Color(0xFF1A0A2E),
                backgroundImage: hasAvatar
                    ? CachedNetworkImageProvider(summary.avatarUrl)
                    : null,
                child: hasAvatar
                    ? null
                    : Icon(
                        summary.type == 'group' ? Icons.group : Icons.person,
                        color: Colors.white54,
                        size: 22,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          summary.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        ChatHelpers.formatInboxTime(summary.lastMessageAt),
                        style: TextStyle(
                          color: hasUnread ? Colors.white70 : Colors.white.withValues(alpha: 0.35),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          summary.lastMessage.isNotEmpty
                              ? summary.lastMessage
                              : 'Tap to start chatting',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasUnread
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.35),
                            fontSize: 13,
                            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.brandDeepMagenta,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.white.withValues(alpha: 0.25),
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
