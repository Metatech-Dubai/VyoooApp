import 'package:flutter/material.dart';

/// Standard interaction button used across the app (reels, stories, posts, etc).
/// Vertical layout: icon above count text.
class AppInteractionButton extends StatelessWidget {
  const AppInteractionButton({
    super.key,
    required this.icon,
    required this.count,
    this.isActive = false,
    this.onTap,
    this.activeColor = const Color(0xFFD10057),
    this.defaultColor = Colors.white,
  });

  final IconData icon;
  final String count;
  final bool isActive;
  final VoidCallback? onTap;
  final Color activeColor;
  final Color defaultColor;

  static const double iconSize = 28;
  static const double textSize = 12;
  static const double spacing = 4;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: iconSize,
            color: isActive ? activeColor : defaultColor,
          ),
          const SizedBox(height: spacing),
          Text(
            count,
            style: TextStyle(
              fontSize: textSize,
              color: isActive ? activeColor : defaultColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
