import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/deep_link_config.dart';
import '../../../core/theme/app_light_surface.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_bottom_sheet.dart';

/// Opens a share sheet with repost (optional), native share, and copy link.
Future<void> showShareBottomSheet(
  BuildContext context, {
  required String reelId,
  String? thumbnailUrl,
  String? authorName,
  required VoidCallback onShareViaNative,
  required VoidCallback onCopyLink,
  bool showRepost = true,
  bool isReposted = false,
  bool isOwnPost = false,
  Future<void> Function()? onRepost,
  Future<void> Function()? onRemoveRepost,
}) {
  final shareUrl = DeepLinkConfig.reelWebUri(reelId).toString();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ShareSheet(
      thumbnailUrl: thumbnailUrl,
      authorName: authorName ?? 'Vyooo',
      shareUrl: shareUrl,
      onShareViaNative: onShareViaNative,
      onCopyLink: () {
        Clipboard.setData(ClipboardData(text: shareUrl));
        onCopyLink();
      },
      showRepost: showRepost && !isOwnPost,
      isReposted: isReposted,
      onRepost: onRepost,
      onRemoveRepost: onRemoveRepost,
    ),
  );
}

class _ShareSheet extends StatelessWidget {
  const _ShareSheet({
    this.thumbnailUrl,
    required this.authorName,
    required this.shareUrl,
    required this.onShareViaNative,
    required this.onCopyLink,
    this.showRepost = false,
    this.isReposted = false,
    this.onRepost,
    this.onRemoveRepost,
  });

  final String? thumbnailUrl;
  final String authorName;
  final String shareUrl;
  final VoidCallback onShareViaNative;
  final VoidCallback onCopyLink;
  final bool showRepost;
  final bool isReposted;
  final Future<void> Function()? onRepost;
  final Future<void> Function()? onRemoveRepost;

  void _openNativeShare(BuildContext context) {
    Navigator.of(context).pop();
    onShareViaNative();
  }

  void _copyLink(BuildContext context) {
    onCopyLink();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet.shell(
      topRadius: 32,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBottomSheet.dragHandle(),
          _TopBar(onClose: () => Navigator.of(context).pop()),
          if (thumbnailUrl != null)
            _ContentHeader(
              thumbnailUrl: thumbnailUrl,
              authorName: authorName,
            ),
          if (showRepost) ...[
            const SizedBox(height: AppSpacing.xs),
            _RepostTile(
              isReposted: isReposted,
              onRepost: onRepost,
              onRemoveRepost: onRemoveRepost,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _ShareActionTile(
            icon: Icons.ios_share_rounded,
            label: 'Share Link',
            onTap: () => _openNativeShare(context),
          ),
          _ShareActionTile(
            icon: Icons.link_rounded,
            label: 'Copy Link',
            onTap: () => _copyLink(context),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _ShareActionTile extends StatelessWidget {
  const _ShareActionTile({
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: AppLightSurface.icon, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppLightSurface.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppLightSurface.chevron,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RepostTile extends StatelessWidget {
  const _RepostTile({
    required this.isReposted,
    this.onRepost,
    this.onRemoveRepost,
  });

  final bool isReposted;
  final Future<void> Function()? onRepost;
  final Future<void> Function()? onRemoveRepost;

  Future<void> _handleTap(BuildContext context) async {
    if (isReposted) {
      await onRemoveRepost?.call();
    } else {
      await onRepost?.call();
    }
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: AppLightSurface.cardFill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppLightSurface.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _handleTap(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  isReposted ? Icons.undo_rounded : Icons.repeat_rounded,
                  color: AppLightSurface.icon,
                  size: 26,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    isReposted
                        ? 'Remove repost from your profile'
                        : 'Repost to your profile',
                    style: TextStyle(
                      color: AppLightSurface.primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          const Spacer(),
          Text(
            'Share',
            style: TextStyle(
              color: AppLightSurface.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onClose,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppLightSurface.cardFill,
                shape: BoxShape.circle,
                border: Border.all(color: AppLightSurface.border),
              ),
              child: Icon(Icons.close, color: AppLightSurface.icon, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentHeader extends StatelessWidget {
  const _ContentHeader({
    this.thumbnailUrl,
    required this.authorName,
  });

  final String? thumbnailUrl;
  final String authorName;

  @override
  Widget build(BuildContext context) {
    final thumb = thumbnailUrl?.trim() ?? '';
    final hasValidThumb = thumb.isNotEmpty &&
        Uri.tryParse(thumb)?.isAbsolute == true &&
        (Uri.tryParse(thumb)?.host.isNotEmpty ?? false);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppLightSurface.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppLightSurface.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppLightSurface.divider,
              borderRadius: BorderRadius.circular(12),
              image: hasValidThumb
                  ? DecorationImage(
                      image: NetworkImage(thumb),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: !hasValidThumb
                ? Icon(Icons.videocam, color: AppLightSurface.mutedText)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Video from $authorName',
                  style: TextStyle(
                    color: AppLightSurface.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Vyooo',
                  style: TextStyle(
                    color: AppLightSurface.mutedText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
