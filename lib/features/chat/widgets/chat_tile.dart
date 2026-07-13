import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_padding.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/chat_summary_model.dart';
import '../utils/chat_constants.dart';
import '../utils/chat_helpers.dart';

class ChatTile extends StatelessWidget {
  const ChatTile({
    super.key,
    required this.summary,
    required this.onTap,
  });

  final ChatSummaryModel summary;
  final VoidCallback onTap;

  bool get _hasMultipleUnread => summary.unreadCount > 1;

  bool get _hasSingleUnread => summary.unreadCount == 1;

  String get _previewBody {
    if (_hasMultipleUnread) {
      return '${summary.unreadCount}+ new messages';
    }
    if (summary.lastMessage.isNotEmpty) {
      return summary.lastMessage;
    }
    return 'Tap to start chatting';
  }

  String get _timeLabel => ChatHelpers.formatInboxTime(summary.lastMessageAt);

  List<InlineSpan> _buildPreviewSpans({
    required double previewFontSize,
    required double previewLineHeight,
  }) {
    final time = _timeLabel;
    final lineHeight = previewLineHeight / previewFontSize;
    final previewStyle = AppTypography.chatInboxTilePreview.copyWith(
      fontSize: previewFontSize,
      height: lineHeight,
    );
    final unreadStyle = AppTypography.chatInboxTilePreviewUnread.copyWith(
      fontSize: previewFontSize,
      height: lineHeight,
    );
    final replyStyle = AppTypography.chatInboxTilePreviewReply.copyWith(
      fontSize: previewFontSize,
      height: lineHeight,
    );
    final timeStyle = AppTypography.chatInboxTileTime.copyWith(
      fontSize: previewFontSize,
      height: lineHeight,
    );

    if (_hasMultipleUnread) {
      return [
        TextSpan(text: _previewBody, style: unreadStyle),
        if (time.isNotEmpty) ...[
          TextSpan(text: ' · ', style: timeStyle),
          TextSpan(text: time, style: timeStyle),
        ],
      ];
    }

    if (_hasSingleUnread) {
      return [
        TextSpan(text: _previewBody, style: previewStyle),
        TextSpan(text: ' · ', style: timeStyle),
        TextSpan(text: 'Reply?', style: replyStyle),
      ];
    }

    return [
      TextSpan(text: _previewBody, style: previewStyle),
      if (time.isNotEmpty) ...[
        TextSpan(text: ' · ', style: timeStyle),
        TextSpan(text: time, style: timeStyle),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final hasAvatar = summary.avatarUrl.trim().isNotEmpty;
    final hasUnread = summary.unreadCount > 0;
    final avatarSize =
        AppSizes.chatInboxScaleW(context, AppSizes.chatInboxAvatar);
    final unreadDotSize =
        AppSizes.chatInboxScaleW(context, AppSizes.chatTileUnreadDot);
    final cameraSize =
        AppSizes.chatInboxScaleW(context, AppSizes.chatTileCamera);
    final verifiedBadgeSize =
        AppSizes.chatInboxScaleW(context, AppSizes.chatTileVerifiedBadge);
    final nameFontSize = AppSizes.chatInboxScaleW(
      context,
      AppSizes.chatInboxTileNameFontSize,
    );
    final nameLineHeight = AppSizes.chatInboxScaleH(
      context,
      AppSizes.chatInboxTileNameLineHeight,
    );
    final previewFontSize = AppSizes.chatInboxScaleW(
      context,
      AppSizes.chatInboxTilePreviewFontSize,
    );
    final previewLineHeight = AppSizes.chatInboxScaleH(
      context,
      AppSizes.chatInboxTilePreviewLineHeight,
    );

    return InkWell(
      onTap: onTap,
      splashColor: AppColors.brandDeepMagenta.withValues(alpha: 0.08),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppPadding.screenHorizontal.left,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: avatarSize / 2,
              backgroundColor: AppColors.chatSearchFill,
              backgroundImage: hasAvatar
                  ? CachedNetworkImageProvider(summary.avatarUrl)
                  : null,
              child: hasAvatar
                  ? null
                  : Icon(
                      summary.type == 'group' ? Icons.group : Icons.person,
                      color: AppColors.chatTextSecondary,
                      size: AppSizes.chatInboxScaleW(
                        context,
                        AppSizes.chatInboxAvatarIcon,
                      ),
                    ),
            ),
            SizedBox(width: AppSpacing.md - AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          summary.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.chatInboxTileName.copyWith(
                            fontSize: nameFontSize,
                            height: nameLineHeight / nameFontSize,
                          ),
                        ),
                      ),
                      if (summary.isVerified) ...[
                        SizedBox(width: AppSpacing.xs - 1),
                        Icon(
                          Icons.verified,
                          color: AppColors.chatVerified,
                          size: verifiedBadgeSize,
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: AppSpacing.xs - 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          TextSpan(
                            children: _buildPreviewSpans(
                              previewFontSize: previewFontSize,
                              previewLineHeight: previewLineHeight,
                            ),
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        SizedBox(width: AppSpacing.sm),
                        SvgPicture.asset(
                          ChatAssets.chatUnreadDot,
                          width: unreadDotSize,
                          height: unreadDotSize,
                        ),
                      ],
                      SizedBox(width: AppSpacing.sm),
                      SvgPicture.asset(
                        ChatAssets.chatTileCamera,
                        width: cameraSize,
                        height: cameraSize,
                      ),
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
