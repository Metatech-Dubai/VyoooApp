import 'package:flutter/material.dart';

import '../../../core/theme/app_background_assets.dart';
import '../../../core/theme/app_spacing.dart';
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

          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(AppBackgroundAssets.postSettings),
                  fit: BoxFit.cover,
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Profile grid size',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    _SpanOption(
                      label: 'Large tile (2×2)',
                      selected:
                          selected == ProfileGridSpanOverride.double,
                      onTap: () => apply(ProfileGridSpanOverride.double),
                    ),
                    _SpanOption(
                      label: 'Normal tile (1×1)',
                      selected: selected == ProfileGridSpanOverride.unit,
                      onTap: () => apply(ProfileGridSpanOverride.unit),
                    ),
                    _SpanOption(
                      label: 'Automatic (views)',
                      selected: selected == ProfileGridSpanOverride.auto,
                      onTap: () => apply(ProfileGridSpanOverride.auto),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ),
              ),
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
        color: selected ? Colors.white : Colors.white54,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.white70,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      onTap: onTap,
    );
  }
}
