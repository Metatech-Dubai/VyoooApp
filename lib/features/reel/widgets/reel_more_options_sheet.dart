import 'package:flutter/material.dart';

import '../../../../core/theme/app_light_surface.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';

/// Shows the three-dots "more options" bottom sheet: Download, Report, Not Interested,
/// then Captions, Playback speed, Quality, Manage preferences, Why you're seeing this.
Future<void> showReelMoreOptionsSheet(
  BuildContext context, {
  required String reelId,
  String playbackSpeed = 'Normal',
  String quality = 'Auto (1080p HD)',
  bool autoScrollEnabled = true,
  VoidCallback? onDownload,
  VoidCallback? onSavePrivately,
  VoidCallback? onReport,
  VoidCallback? onNotInterested,
  VoidCallback? onCaptions,
  VoidCallback? onPlaybackSpeed,
  VoidCallback? onQuality,
  VoidCallback? onManagePreferences,
  VoidCallback? onWhyThisPost,
  ValueChanged<bool>? onAutoScrollChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ReelMoreOptionsSheet(
      reelId: reelId,
      playbackSpeed: playbackSpeed,
      quality: quality,
      autoScrollEnabled: autoScrollEnabled,
      onDownload: onDownload,
      onSavePrivately: onSavePrivately,
      onReport: onReport,
      onNotInterested: onNotInterested,
      onCaptions: onCaptions,
      onPlaybackSpeed: onPlaybackSpeed,
      onQuality: onQuality,
      onManagePreferences: onManagePreferences,
      onWhyThisPost: onWhyThisPost,
      onAutoScrollChanged: onAutoScrollChanged,
    ),
  );
}

class _ReelMoreOptionsSheet extends StatefulWidget {
  const _ReelMoreOptionsSheet({
    required this.reelId,
    required this.playbackSpeed,
    required this.quality,
    required this.autoScrollEnabled,
    this.onDownload,
    this.onSavePrivately,
    this.onReport,
    this.onNotInterested,
    this.onCaptions,
    this.onPlaybackSpeed,
    this.onQuality,
    this.onManagePreferences,
    this.onWhyThisPost,
    this.onAutoScrollChanged,
  });

  final String reelId;
  final String playbackSpeed;
  final String quality;
  final bool autoScrollEnabled;
  final VoidCallback? onDownload;
  final VoidCallback? onSavePrivately;
  final VoidCallback? onReport;
  final VoidCallback? onNotInterested;
  final VoidCallback? onCaptions;
  final VoidCallback? onPlaybackSpeed;
  final VoidCallback? onQuality;
  final VoidCallback? onManagePreferences;
  final VoidCallback? onWhyThisPost;
  final ValueChanged<bool>? onAutoScrollChanged;

  @override
  State<_ReelMoreOptionsSheet> createState() => _ReelMoreOptionsSheetState();
}

class _ReelMoreOptionsSheetState extends State<_ReelMoreOptionsSheet> {
  late bool _autoScroll;

  @override
  void initState() {
    super.initState();
    _autoScroll = widget.autoScrollEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.75,
      builder: (context, scrollController) {
        return Container(
          decoration: AppBottomSheet.decoration(topRadius: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBottomSheet.dragHandle(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.download_rounded,
                        label: 'Download',
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onDownload?.call();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.report_outlined,
                        label: 'Report',
                        iconColor: const Color(0xFFEF4444),
                        labelColor: const Color(0xFFEF4444),
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onReport?.call();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.favorite_border,
                        label: 'Not Interested',
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onNotInterested?.call();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  children: [
                    _Section(
                      children: [
                        if (widget.onSavePrivately != null)
                          _SettingTile(
                            icon: Icons.bookmark_add_outlined,
                            label: 'Save Privately',
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onSavePrivately?.call();
                            },
                          ),
                        _AutoScrollTile(
                          enabled: _autoScroll,
                          onChanged: (value) {
                            setState(() => _autoScroll = value);
                            widget.onAutoScrollChanged?.call(value);
                          },
                        ),
                        _SettingTile(
                          icon: Icons.closed_caption_outlined,
                          label: 'Captions And Translations',
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onCaptions?.call();
                          },
                        ),
                        _SettingTile(
                          icon: Icons.speed_rounded,
                          label: 'Playback Speed',
                          trailing: widget.playbackSpeed,
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onPlaybackSpeed?.call();
                          },
                        ),
                        _SettingTile(
                          icon: Icons.tune_rounded,
                          label: 'Quality',
                          trailing: widget.quality,
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onQuality?.call();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _Section(
                      children: [
                        _SettingTile(
                          icon: Icons.shuffle_rounded,
                          label: 'Manage Content Preferences',
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onManagePreferences?.call();
                          },
                        ),
                        _SettingTile(
                          icon: Icons.info_outline_rounded,
                          label: "Why You're Seeing This Post",
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onWhyThisPost?.call();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AutoScrollTile extends StatelessWidget {
  const _AutoScrollTile({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!enabled),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.play_circle_outline_rounded,
              size: 22,
              color: AppLightSurface.icon,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Auto scroll',
                style: TextStyle(
                  color: AppLightSurface.primaryText,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            SizedBox(
              height: 24,
              width: 40,
              child: Switch.adaptive(
                value: enabled,
                onChanged: onChanged,
                activeTrackColor: const Color(0xFFEF4444),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.iconColor,
    this.labelColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;
  final Color? labelColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppLightSurface.icon;
    final textColor = labelColor ?? AppLightSurface.primaryText;
    return Material(
      color: AppLightSurface.cardFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppLightSurface.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppLightSurface.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppLightSurface.border),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.label,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppLightSurface.icon),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: AppLightSurface.primaryText,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            if (trailing != null) ...[
              Text(
                trailing!,
                style: TextStyle(
                  color: AppLightSurface.mutedText,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
            ],
            Icon(
              Icons.chevron_right,
              size: 20,
              color: AppLightSurface.chevron,
            ),
          ],
        ),
      ),
    );
  }
}
