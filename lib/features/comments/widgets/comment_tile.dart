import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../models/comment.dart';

/// Single comment row: avatar, username, time, text, Reply/View replies, like or delete.
class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.comment,
    this.isReply = false,
    this.onReply,
    this.onLike,
    this.onViewReplies,
    this.onDelete,
  });

  final Comment comment;
  final bool isReply;
  final VoidCallback? onReply;
  final VoidCallback? onLike;
  final VoidCallback? onViewReplies;
  final VoidCallback? onDelete;

  static const double _avatarSize = 40;
  static const double _avatarSizeReply = 32;

  @override
  Widget build(BuildContext context) {
    final avatarSize = isReply ? _avatarSizeReply : _avatarSize;
    return Padding(
      padding: EdgeInsets.only(
        left: isReply ? AppSpacing.xl + _avatarSize : 0,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: avatarSize / 2,
            backgroundColor: Colors.grey.shade700,
            backgroundImage: Uri.tryParse(comment.avatarUrl)?.isAbsolute == true
                ? NetworkImage(comment.avatarUrl)
                : null,
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Row(
                        children: [
                          Text(
                            comment.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (comment.isVerified) ...[
                            SizedBox(width: AppSpacing.xs),
                            _VerifiedBadge(),
                          ],
                          SizedBox(width: AppSpacing.xs),
                          Text(
                            comment.timeAgo,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  comment.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onReply,
                      child: Text(
                        'Reply',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (comment.replyCount > 0) ...[
                      SizedBox(width: AppSpacing.md),
                      GestureDetector(
                        onTap: onViewReplies,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View more replies (${comment.replyCount})',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          if (comment.isOwnComment)
            GestureDetector(
              onTap: onDelete,
              child: const Icon(
                Icons.delete_outlined,
                size: 22,
                color: AppColors.deleteRed,
              ),
            )
          else
            GestureDetector(
              onTap: onLike,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    comment.isLiked ? Icons.favorite : Icons.favorite_border,
                    size: 18,
                    color: comment.isLiked
                        ? AppColors.pink
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                  if (comment.likeCount > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      '${comment.likeCount}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: const BoxDecoration(
        color: AppColors.pink,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check, size: 10, color: Colors.white),
    );
  }
}
