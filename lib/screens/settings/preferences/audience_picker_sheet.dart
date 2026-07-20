import 'package:flutter/material.dart';

import '../../../core/models/user_app_preferences.dart';
import '../../../core/theme/app_light_surface.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_bottom_sheet.dart';

Future<String?> showAudiencePickerSheet(
  BuildContext context, {
  required String title,
  required String currentValue,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return AppBottomSheet.shell(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBottomSheet.dragHandle(),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                title,
                style: AppTypography.onboardingSectionTitle.copyWith(
                  fontSize: 18,
                  color: AppLightSurface.primaryText,
                ),
              ),
            ),
            for (final value in AudienceOption.values)
              ListTile(
                title: Text(
                  AudienceOption.labels[value] ?? value,
                  style: AppTypography.authDialogOption.copyWith(
                    color: AppLightSurface.primaryText,
                  ),
                ),
                trailing: currentValue == value
                    ? const Icon(Icons.check_rounded, color: AppLightSurface.primaryText)
                    : null,
                onTap: () => Navigator.pop(ctx, value),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      );
    },
  );
}
