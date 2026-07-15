import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_light_surface.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';

/// Video quality options. [isPremium] shows yellow PREMIUM tag.
const List<VideoQualityOption> kVideoQualityOptions = [
  VideoQualityOption(id: 'auto', label: 'Auto', isPremium: false),
  VideoQualityOption(id: 'max', label: 'Max (4k)', isPremium: true),
  VideoQualityOption(id: 'high', label: 'High (1080p)', isPremium: true),
  VideoQualityOption(id: 'medium', label: 'Medium (720p)', isPremium: true),
  VideoQualityOption(id: 'low', label: 'Low (480p)', isPremium: false),
];

class VideoQualityOption {
  const VideoQualityOption({
    required this.id,
    required this.label,
    this.isPremium = false,
  });
  final String id;
  final String label;
  final bool isPremium;
}

void showVideoQualitySheet(
  BuildContext context, {
  required String selectedId,
  required void Function(String id, String label) onSelected,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _VideoQualitySheet(
      selectedId: selectedId,
      onSelected: onSelected,
    ),
  );
}

class _VideoQualitySheet extends StatelessWidget {
  const _VideoQualitySheet({
    required this.selectedId,
    required this.onSelected,
  });

  final String selectedId;
  final void Function(String id, String label) onSelected;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.28,
      maxChildSize: 0.65,
      builder: (context, scrollController) {
        return Container(
          decoration: AppBottomSheet.decoration(topRadius: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBottomSheet.dragHandle(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  'Video Quality',
                  style: TextStyle(
                    color: AppLightSurface.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  itemCount: kVideoQualityOptions.length,
                  itemBuilder: (context, index) {
                    final option = kVideoQualityOptions[index];
                    final isSelected = option.id == selectedId;
                    return InkWell(
                      onTap: () {
                        onSelected(option.id, option.label);
                        Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                option.label,
                                style: TextStyle(
                                  color: AppLightSurface.primaryText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            if (option.isPremium)
                              Container(
                                margin: const EdgeInsets.only(
                                  right: AppSpacing.sm,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.lightGold.withValues(
                                    alpha: 0.25,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'PREMIUM',
                                  style: TextStyle(
                                    color: AppColors.lightGold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (isSelected)
                              const Icon(
                                Icons.check,
                                color: AppColors.whatsappGreen,
                                size: 24,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }
}
