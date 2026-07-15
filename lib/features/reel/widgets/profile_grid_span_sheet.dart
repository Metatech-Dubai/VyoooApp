import 'package:flutter/material.dart';

import '../../../core/theme/app_light_surface.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/profile/profile_grid_models.dart';
import '../../../core/widgets/profile/profile_grid_span_service.dart';
import '../../../core/widgets/profile/profile_modular_grid.dart';

/// Pick large / normal / automatic tile size for a profile grid post.
Future<void> showProfileGridSpanSheet({
  required BuildContext context,
  required Map<String, dynamic> post,
}) {
  final reelId = (post['id'] as String? ?? '').trim();
  final ownerUid = (post['userId'] as String? ?? '').trim();
  if (reelId.isEmpty || ownerUid.isEmpty) return Future.value();

  var selected = profileGridSpanOverrideFromReel(post);

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> apply(ProfileGridSpanOverride span) async {
            setSheetState(() => selected = span);
            final ok = await ProfileGridSpanService.updateSpan(
              reelId: reelId,
              ownerUserId: ownerUid,
              span: span,
            );
            if (!context.mounted) return;
            if (ok) {
              post['profileGridSpan'] = profileGridSpanToFirestore(span);
              if (ctx.mounted) Navigator.of(ctx).pop();
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not update grid size. Try again.'),
              ),
            );
          }

          return AppBottomSheet.shell(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBottomSheet.dragHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Profile grid size',
                      style: TextStyle(
                        color: AppLightSurface.primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                _SpanOption(
                  label: 'Large Tile (2×2)',
                  selected: selected == ProfileGridSpanOverride.double,
                  onTap: () => apply(ProfileGridSpanOverride.double),
                ),
                _SpanOption(
                  label: 'Normal Tile (1×1)',
                  selected: selected == ProfileGridSpanOverride.unit,
                  onTap: () => apply(ProfileGridSpanOverride.unit),
                ),
                _SpanOption(
                  label: 'Automatic (Views)',
                  selected: selected == ProfileGridSpanOverride.auto,
                  onTap: () => apply(ProfileGridSpanOverride.auto),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          );
        },
      );
    },
  );
}

class _SpanOption extends StatelessWidget {
  const _SpanOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? AppLightSurface.icon : AppLightSurface.mutedText,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: selected
              ? AppLightSurface.primaryText
              : AppLightSurface.secondaryText,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      onTap: onTap,
    );
  }
}
