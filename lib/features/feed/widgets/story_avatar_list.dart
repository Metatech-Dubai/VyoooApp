import 'package:flutter/material.dart';

import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_padding.dart';
import '../../../../core/theme/app_spacing.dart';

/// Horizontal list of story avatars with pink gradient border ring.
class StoryAvatarList extends StatelessWidget {
  const StoryAvatarList({
    super.key,
    required this.avatars,
    this.onAvatarTap,
  });

  /// List of { 'id': String, 'url': String }
  final List<Map<String, String>> avatars;
  final void Function(String id)? onAvatarTap;

  static const double _size = 64;
  static const double _borderWidth = 3;
  static const double _spacing = 12;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _size + _borderWidth * 2 + 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppPadding.screenHorizontal.copyWith(
          top: AppSpacing.sm,
          bottom: AppSpacing.sm,
        ),
        itemCount: avatars.length,
        separatorBuilder: (_, __) => const SizedBox(width: _spacing),
        itemBuilder: (context, index) {
          final a = avatars[index];
          final id = a['id'] ?? '$index';
          final url = a['url'] ?? '';
          return _StoryRing(
            size: _size,
            imageUrl: url,
            borderWidth: _borderWidth,
            onTap: () => onAvatarTap?.call(id),
          );
        },
      ),
    );
  }
}

class _StoryRing extends StatelessWidget {
  const _StoryRing({
    required this.size,
    required this.imageUrl,
    required this.borderWidth,
    required this.onTap,
  });

  final double size;
  final String imageUrl;
  final double borderWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size + borderWidth * 2,
        height: size + borderWidth * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppGradients.storyRingGradient,
        ),
        padding: EdgeInsets.all(borderWidth),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black,
          ),
          clipBehavior: Clip.antiAlias,
          child: imageUrl.isEmpty
              ? Icon(Icons.person, size: size * 0.5, color: Colors.white54)
              : Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.person,
                    size: size * 0.5,
                    color: Colors.white54,
                  ),
                ),
        ),
      ),
    );
  }
}
