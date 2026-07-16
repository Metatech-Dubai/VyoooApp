import 'package:flutter/material.dart';

import '../../../../core/theme/app_light_surface.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';

/// "Not interested" confirmation sheet. Shown when user taps Not Interested in more-options.
void showNotInterestedSheet(BuildContext context, {String? reelId}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _NotInterestedSheet(),
  );
}

class _NotInterestedSheet extends StatelessWidget {
  const _NotInterestedSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppBottomSheet.decoration(topRadius: AppRadius.pill),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBottomSheet.dragHandle(),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Not interested?',
              style: TextStyle(
                color: AppLightSurface.primaryText,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Text(
                "We'll show less content like this in your feed.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppLightSurface.secondaryText,
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor: AppLightSurface.cardFill,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                      side: BorderSide(color: AppLightSurface.border),
                    ),
                  ),
                  child: Text(
                    'Got it',
                    style: TextStyle(
                      color: AppLightSurface.primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
