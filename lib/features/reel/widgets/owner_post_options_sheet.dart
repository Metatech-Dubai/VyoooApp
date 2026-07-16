import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/reel_count_privacy.dart';
import '../../../core/theme/app_light_surface.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import 'profile_grid_span_sheet.dart';
import 'profile_grid_title_sheet.dart';

/// Bottom sheet for posts you own: caption, delete, and counter privacy toggles.
Future<void> showOwnerPostOptionsSheet({
  required BuildContext context,
  required Map<String, dynamic> post,
  required bool isVideo,
  required Future<void> Function(String field, bool hidden) onPrivacyChanged,
  required VoidCallback onEditCaption,
  required VoidCallback onDelete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      var privacy = ReelCountPrivacy.fromMap(post);
      return StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> toggle(
            String field,
            bool Function(ReelCountPrivacy) read,
            ReelCountPrivacy Function(ReelCountPrivacy, bool) write,
          ) async {
            final nextHidden = !read(privacy);
            final nextPrivacy = write(privacy, nextHidden);
            setSheetState(() => privacy = nextPrivacy);
            post
              ..['hideLikeCount'] = nextPrivacy.hideLikeCount
              ..['hideViewCount'] = nextPrivacy.hideViewCount
              ..['hideShareCount'] = nextPrivacy.hideShareCount
              ..['hideCommentCount'] = nextPrivacy.hideCommentCount
              ..['hideSaveCount'] = nextPrivacy.hideSaveCount;
            await onPrivacyChanged(field, nextHidden);
          }

          return AppBottomSheet.shell(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBottomSheet.dragHandle(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Post settings',
                        style: TextStyle(
                          color: AppLightSurface.primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Hide counts from everyone on this post.',
                        style: TextStyle(
                          color: AppLightSurface.secondaryText,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                  SwitchListTile(
                    title: Text(
                      'Hide like count',
                      style: TextStyle(color: AppLightSurface.primaryText),
                    ),
                    value: privacy.hideLikeCount,
                    activeThumbColor: AppColors.brandPink,
                    onChanged: (_) => toggle(
                      'hideLikeCount',
                      (p) => p.hideLikeCount,
                      (p, v) => p.copyWith(hideLikeCount: v),
                    ),
                  ),
                  SwitchListTile(
                    title: Text(
                      'Hide view count',
                      style: TextStyle(color: AppLightSurface.primaryText),
                    ),
                    value: privacy.hideViewCount,
                    activeThumbColor: AppColors.brandPink,
                    onChanged: (_) => toggle(
                      'hideViewCount',
                      (p) => p.hideViewCount,
                      (p, v) => p.copyWith(hideViewCount: v),
                    ),
                  ),
                  SwitchListTile(
                    title: Text(
                      'Hide repost count',
                      style: TextStyle(color: AppLightSurface.primaryText),
                    ),
                    value: privacy.hideShareCount,
                    activeThumbColor: AppColors.brandPink,
                    onChanged: (_) => toggle(
                      'hideShareCount',
                      (p) => p.hideShareCount,
                      (p, v) => p.copyWith(hideShareCount: v),
                    ),
                  ),
                  SwitchListTile(
                    title: Text(
                      'Hide comment count',
                      style: TextStyle(color: AppLightSurface.primaryText),
                    ),
                    value: privacy.hideCommentCount,
                    activeThumbColor: AppColors.brandPink,
                    onChanged: (_) => toggle(
                      'hideCommentCount',
                      (p) => p.hideCommentCount,
                      (p, v) => p.copyWith(hideCommentCount: v),
                    ),
                  ),
                  SwitchListTile(
                    title: Text(
                      'Hide save count',
                      style: TextStyle(color: AppLightSurface.primaryText),
                    ),
                    value: privacy.hideSaveCount,
                    activeThumbColor: AppColors.brandPink,
                    onChanged: (_) => toggle(
                      'hideSaveCount',
                      (p) => p.hideSaveCount,
                      (p, v) => p.copyWith(hideSaveCount: v),
                    ),
                  ),
                  Divider(color: AppLightSurface.divider, height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.grid_view_rounded,
                      color: AppLightSurface.icon,
                    ),
                    title: Text(
                      'Profile grid size',
                      style: TextStyle(color: AppLightSurface.primaryText),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      showProfileGridSpanSheet(
                        context: context,
                        post: post,
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.short_text_rounded,
                      color: AppLightSurface.icon,
                    ),
                    title: Text(
                      'Profile grid title & thumbnail',
                      style: TextStyle(color: AppLightSurface.primaryText),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      showProfileGridTitleSheet(
                        context: context,
                        post: post,
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.edit_rounded,
                      color: AppLightSurface.icon,
                    ),
                    title: Text(
                      isVideo ? 'Edit video caption' : 'Edit photo caption',
                      style: TextStyle(color: AppLightSurface.primaryText),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onEditCaption();
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.deleteRed,
                    ),
                    title: const Text(
                      'Delete post',
                      style: TextStyle(color: AppColors.deleteRed),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onDelete();
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
