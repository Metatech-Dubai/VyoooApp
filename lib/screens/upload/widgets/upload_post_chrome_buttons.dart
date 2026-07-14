import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Photo vs video preview — controls edit pill label/asset.
enum UploadPreviewMediaType {
  photo,
  video,
}

/// Figma post-upload chrome buttons (close, edit media, next).
abstract final class UploadPostChromeAssets {
  static const String closeButton =
      'assets/vyooO_icons/Upload_Story_Live/upload_post_close_button.svg';
  static const String editVideoButton =
      'assets/vyooO_icons/Upload_Story_Live/upload_edit_video_button.svg';
  static const String editPencilIcon =
      'assets/vyooO_icons/Upload_Story_Live/edit_video.png';
  static const String nextButton =
      'assets/vyooO_icons/Upload_Story_Live/upload_next_button.svg';
  static const String detailsUploadButton =
      'assets/vyooO_icons/Upload_Story_Live/upload_details_upload_button.svg';
}

class UploadPostCloseButton extends StatelessWidget {
  const UploadPostCloseButton({
    super.key,
    required this.onTap,
    this.size = AppSizes.uploadPostCloseButton,
  });

  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSizes.uploadPostCloseHitTarget,
      height: AppSizes.uploadPostCloseHitTarget,
      child: Center(
        child: _ChromeSvgButton(
          assetPath: UploadPostChromeAssets.closeButton,
          width: size,
          height: size,
          onTap: onTap,
          borderRadius: size / 2,
        ),
      ),
    );
  }
}

class UploadEditMediaButton extends StatelessWidget {
  const UploadEditMediaButton({
    super.key,
    required this.mediaType,
    required this.onTap,
  });

  final UploadPreviewMediaType mediaType;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (mediaType == UploadPreviewMediaType.video) {
      return _ChromeSvgButton(
        assetPath: UploadPostChromeAssets.editVideoButton,
        width: AppSizes.uploadEditMediaButtonWidth,
        height: AppSizes.uploadEditMediaButtonHeight,
        onTap: onTap,
        borderRadius: AppSizes.uploadEditMediaButtonHeight / 2,
      );
    }

    return _EditPhotoPillButton(onTap: onTap);
  }
}

class _EditPhotoPillButton extends StatelessWidget {
  const _EditPhotoPillButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          AppSizes.uploadEditMediaButtonHeight / 2,
        ),
        splashColor: Colors.white24,
        highlightColor: Colors.white12,
        child: Ink(
          height: AppSizes.uploadEditMediaButtonHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: AppColors.uploadEditMediaPill,
            borderRadius: BorderRadius.circular(
              AppSizes.uploadEditMediaButtonHeight / 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Edit Photo', style: AppTypography.uploadEditMediaPillLabel),
              const SizedBox(width: AppSpacing.xs),
              Image.asset(
                UploadPostChromeAssets.editPencilIcon,
                width: 12,
                height: 12,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UploadNextPillButton extends StatelessWidget {
  const UploadNextPillButton({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ChromeSvgButton(
      assetPath: UploadPostChromeAssets.nextButton,
      width: AppSizes.uploadNextPillButtonWidth,
      height: AppSizes.uploadNextPillButtonHeight,
      onTap: onTap,
      borderRadius: AppSizes.uploadNextPillButtonHeight / 2,
    );
  }
}

/// Figma Add details header Upload pill — 85×35 / #1A1A1A.
class UploadDetailsUploadButton extends StatelessWidget {
  const UploadDetailsUploadButton({
    super.key,
    required this.onTap,
    this.enabled = true,
    this.isLoading = false,
  });

  final VoidCallback? onTap;
  final bool enabled;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        width: AppSizes.uploadDetailsUploadButtonWidth,
        height: AppSizes.uploadDetailsUploadButtonHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(
              AppSizes.uploadDetailsUploadButtonHeight / 2,
            ),
          ),
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }

    final child = _ChromeSvgButton(
      assetPath: UploadPostChromeAssets.detailsUploadButton,
      width: AppSizes.uploadDetailsUploadButtonWidth,
      height: AppSizes.uploadDetailsUploadButtonHeight,
      onTap: enabled ? onTap : null,
      borderRadius: AppSizes.uploadDetailsUploadButtonHeight / 2,
    );
    if (enabled) return child;
    return Opacity(opacity: 0.45, child: child);
  }
}

/// Media preview header row — close (left), edit + next (right).
class UploadMediaPreviewToolbar extends StatelessWidget {
  const UploadMediaPreviewToolbar({
    super.key,
    required this.mediaType,
    required this.onCloseTap,
    required this.onEditTap,
    required this.onNextTap,
    this.showEditButton = true,
  });

  final UploadPreviewMediaType mediaType;
  final VoidCallback onCloseTap;
  final VoidCallback onEditTap;
  final VoidCallback onNextTap;
  final bool showEditButton;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.uploadMediaPreviewToolbarHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          UploadPostCloseButton(onTap: onCloseTap),
          const Spacer(),
          if (showEditButton) ...[
            UploadEditMediaButton(
              mediaType: mediaType,
              onTap: onEditTap,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          UploadNextPillButton(onTap: onNextTap),
        ],
      ),
    );
  }
}

class _ChromeSvgButton extends StatelessWidget {
  const _ChromeSvgButton({
    required this.assetPath,
    required this.width,
    required this.height,
    required this.onTap,
    required this.borderRadius,
  });

  final String assetPath;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        splashColor: Colors.white24,
        highlightColor: Colors.white12,
        child: SizedBox(
          width: width,
          height: height,
          child: SvgPicture.asset(
            assetPath,
            width: width,
            height: height,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
