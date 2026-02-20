import 'package:flutter/material.dart';

import '../../../../core/theme/app_padding.dart';
import '../../../../core/theme/app_spacing.dart';


/// Horizontal story row for Following tab. Circular avatars with thin purple border (Figma).
class FollowingHeaderStories extends StatelessWidget {
  const FollowingHeaderStories({
    super.key,
    required this.stories,
    this.selectedId,
    this.onStoryTap,
  });

  final List<Map<String, dynamic>> stories;
  final String? selectedId;
  final void Function(String id)? onStoryTap;

  static const double _itemSize = 56;
  static const double _borderWidth = 2;

  static const Color _borderColor = Color(0xFF8B5A9E);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppPadding.screenHorizontal.copyWith(
          top: AppSpacing.sm,
          bottom: AppSpacing.md,
        ),
        itemCount: stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.storyItem),
        itemBuilder: (context, index) {
          final story = stories[index];
          final id = story['id'] as String? ?? '$index';
          final imageUrl = story['profileImage'] as String? ?? story['avatarUrl'] as String? ?? '';
          final isSelected = selectedId == id;
          return _StoryCircle(
            size: _itemSize,
            imageUrl: imageUrl,
            isSelected: isSelected,
            borderColor: _borderColor,
            borderWidth: _borderWidth,
            onTap: () => onStoryTap?.call(id),
          );
        },
      ),
    );
  }
}

class _StoryCircle extends StatefulWidget {
  const _StoryCircle({
    required this.size,
    required this.imageUrl,
    required this.isSelected,
    required this.borderColor,
    required this.borderWidth,
    required this.onTap,
  });

  final double size;
  final String imageUrl;
  final bool isSelected;
  final Color borderColor;
  final double borderWidth;
  final VoidCallback onTap;

  @override
  State<_StoryCircle> createState() => _StoryCircleState();
}

class _StoryCircleState extends State<_StoryCircle> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: widget.isSelected ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: widget.size + widget.borderWidth * 2,
          height: widget.size + widget.borderWidth * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.borderColor,
              width: widget.borderWidth,
            ),
          ),
          padding: EdgeInsets.all(widget.borderWidth),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
            ),
            clipBehavior: Clip.antiAlias,
            child: (widget.imageUrl.isNotEmpty)
                ? Image.network(
                    widget.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholderIcon(),
                  )
                : _placeholderIcon(),
          ),
        ),
      ),
    );
  }

  Widget _placeholderIcon() {
    return Icon(
      Icons.person_rounded,
      size: widget.size * 0.5,
      color: Colors.white.withValues(alpha: 0.5),
    );
  }
}
