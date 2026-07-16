import 'package:flutter/material.dart';

import '../../../core/services/comment_service.dart';
import '../../../core/services/story_comment_service.dart';
import '../../../core/theme/app_light_surface.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/user_facing_errors.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../models/comment.dart';

/// Bottom sheet: pick a reason and write to `comment_reports`.
Future<void> showReportCommentSheet(
  BuildContext context, {
  String? reelId,
  String? storyId,
  required Comment comment,
}) async {
  assert(
    (reelId != null && reelId.isNotEmpty && (storyId == null || storyId.isEmpty)) ||
        (storyId != null && storyId.isNotEmpty && (reelId == null || reelId.isEmpty)),
    'Provide either reelId or storyId',
  );
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ReportCommentBody(
      reelId: reelId ?? '',
      storyId: storyId ?? '',
      forStory: storyId != null && storyId.isNotEmpty,
      comment: comment,
    ),
  );
}

class _ReportCommentBody extends StatefulWidget {
  const _ReportCommentBody({
    required this.reelId,
    required this.storyId,
    required this.forStory,
    required this.comment,
  });

  final String reelId;
  final String storyId;
  final bool forStory;
  final Comment comment;

  @override
  State<_ReportCommentBody> createState() => _ReportCommentBodyState();
}

class _ReportCommentBodyState extends State<_ReportCommentBody> {
  static const _reasons = [
    'Spam or misleading',
    'Harassment or hate',
    'Nudity or sexual content',
    'Violence or dangerous acts',
    'Something else',
  ];

  bool _submitting = false;

  Future<void> _submit(String reason) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      if (widget.forStory) {
        await StoryCommentService().reportComment(
          storyId: widget.storyId,
          commentId: widget.comment.id,
          commentAuthorId: widget.comment.authorUserId,
          reason: reason,
        );
      } else {
        await CommentService().reportComment(
          reelId: widget.reelId,
          commentId: widget.comment.id,
          commentAuthorId: widget.comment.authorUserId,
          reason: reason,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanks — we\'ll review this comment.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(messageForFirestore(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppBottomSheet.decoration(topRadius: 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBottomSheet.dragHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text(
                'Report @${widget.comment.username}',
                style: TextStyle(
                  color: AppLightSurface.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                widget.comment.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppLightSurface.secondaryText,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_submitting)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppLightSurface.mutedText,
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                child: Column(
                  children: [
                    for (var i = 0; i < _reasons.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, color: AppLightSurface.divider),
                      ListTile(
                        title: Text(
                          _reasons[i],
                          style: TextStyle(
                            color: AppLightSurface.primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: AppLightSurface.chevron,
                        ),
                        onTap: () => _submit(_reasons[i]),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
