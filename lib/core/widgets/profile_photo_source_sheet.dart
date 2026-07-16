import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_light_surface.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Where the user chose to pick a profile photo from.
enum ProfilePhotoPickSource {
  gallery,
  camera,
}

/// Profile photo picker — same auth/onboarding look on Android and iOS.
Future<ProfilePhotoPickSource?> showProfilePhotoSourceSheet(
  BuildContext context,
) {
  return showModalBottomSheet<ProfilePhotoPickSource>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    isScrollControlled: true,
    enableDrag: true,
    useSafeArea: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => const _ProfilePhotoSourceSheet(),
  );
}

/// White sheet backdrop for profile photo picker.
class _AuthFlowSheetBackdrop extends StatelessWidget {
  const _AuthFlowSheetBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppLightSurface.background,
      child: child,
    );
  }
}

class _ProfilePhotoSourceSheet extends StatelessWidget {
  const _ProfilePhotoSourceSheet();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: _AuthFlowSheetBackdrop(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom > 0 ? bottom : AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppLightSurface.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _SourceRow(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onTap: () => Navigator.pop(
                  context,
                  ProfilePhotoPickSource.gallery,
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: AppLightSurface.divider,
                indent: AppSpacing.md,
                endIndent: AppSpacing.md,
              ),
              _SourceRow(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                onTap: () => Navigator.pop(
                  context,
                  ProfilePhotoPickSource.camera,
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: AppLightSurface.divider,
              ),
              _CancelRow(
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md + 2,
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.brandPink, size: 26),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.input.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppLightSurface.primaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CancelRow extends StatelessWidget {
  const _CancelRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md + 2),
          child: Center(
            child: Text(
              'Cancel',
              style: AppTypography.input.copyWith(
                fontWeight: FontWeight.w600,
                color: AppLightSurface.secondaryText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
