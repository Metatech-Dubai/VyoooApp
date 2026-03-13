import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_gradients.dart';

/// Asset paths for bottom nav icons (selected / unselected).
class _NavAssets {
  static const _base = 'assets/BottomNavBar';
  static const homeSelected = '$_base/HomeSelected.png';
  static const homeUnselected = '$_base/HomeUnSlected.png';
  static const searchSelected = '$_base/SearchSelected.png';
  static const searchUnselected = '$_base/SearchUnSelected.png';
  static const addSelected = '$_base/AddSelected.png';
  static const addUnselected = '$_base/addUnSelectedv1.png';
  static const notificationSelected = '$_base/NotificationSelected.png';
  static const notificationUnselected = '$_base/NotificationUnSelected.png';
}

/// Custom bottom navigation. No BottomNavigationBar — gradient background, parent controls index via onTap.
/// Index: 0 Home, 1 Search, 2 Create (+), 3 Notifications, 4 Profile.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.profileImageUrl,
  });

  final int currentIndex;
  final void Function(int) onTap;
  final String? profileImageUrl;

  static const double _barHeight = 64;
  static const double _iconSize = 26;
  static const double _profileSize = 36;
  static const double _addButtonSize = 32;
  static const double _addButtonRadius = 8;
  static const Duration _animDuration = Duration(milliseconds: 150);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _barHeight,
      decoration: const BoxDecoration(
        gradient: AppGradients.feedGradient,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _NavItem(
            selectedAsset: _NavAssets.homeSelected,
            unselectedAsset: _NavAssets.homeUnselected,
            fallbackIcon: Icons.home_rounded,
            index: 0,
            currentIndex: currentIndex,
            onTap: onTap,
            iconSize: _iconSize,
            animDuration: _animDuration,
          ),
          _NavItem(
            selectedAsset: _NavAssets.searchSelected,
            unselectedAsset: _NavAssets.searchUnselected,
            fallbackIcon: Icons.search_rounded,
            index: 1,
            currentIndex: currentIndex,
            onTap: onTap,
            iconSize: _iconSize,
            animDuration: _animDuration,
          ),
          _AddButton(
            selectedAsset: _NavAssets.addSelected,
            unselectedAsset: _NavAssets.addUnselected,
            isSelected: currentIndex == 2,
            size: _addButtonSize,
            radius: _addButtonRadius,
            iconSize: _iconSize,
            onTap: () {
              HapticFeedback.lightImpact();
              onTap(2);
            },
          ),
          _NavItem(
            selectedAsset: _NavAssets.notificationSelected,
            unselectedAsset: _NavAssets.notificationUnselected,
            fallbackIcon: Icons.notifications_outlined,
            index: 3,
            currentIndex: currentIndex,
            onTap: onTap,
            iconSize: _iconSize,
            animDuration: _animDuration,
          ),
          _ProfileItem(
            index: 4,
            currentIndex: currentIndex,
            onTap: onTap,
            imageUrl: profileImageUrl,
            size: _profileSize,
            animDuration: _animDuration,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.selectedAsset,
    required this.unselectedAsset,
    required this.fallbackIcon,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    required this.iconSize,
    required this.animDuration,
  });

  final String selectedAsset;
  final String unselectedAsset;
  final IconData fallbackIcon;
  final int index;
  final int currentIndex;
  final void Function(int) onTap;
  final double iconSize;
  final Duration animDuration;

  @override
  Widget build(BuildContext context) {
    final isSelected = index == currentIndex;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap(index);
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: AnimatedScale(
            scale: isSelected ? 1.12 : 1.0,
            duration: animDuration,
            child: SizedBox(
              width: iconSize,
              height: iconSize,
              child: Image.asset(
                isSelected ? selectedAsset : unselectedAsset,
                fit: BoxFit.contain,
                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.55),
                colorBlendMode: BlendMode.modulate,
                errorBuilder: (ctx, err, stack) => Icon(
                  fallbackIcon,
                  size: iconSize,
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.selectedAsset,
    required this.unselectedAsset,
    required this.isSelected,
    required this.size,
    required this.radius,
    required this.iconSize,
    required this.onTap,
  });

  final String selectedAsset;
  final String unselectedAsset;
  final bool isSelected;
  final double size;
  final double radius;
  final double iconSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Image.asset(
                isSelected ? selectedAsset : unselectedAsset,
                width: iconSize - 4,
                height: iconSize - 4,
                fit: BoxFit.contain,
                color: Colors.white,
                colorBlendMode: BlendMode.modulate,
                errorBuilder: (ctx, err, stack) => Icon(
                  Icons.add_rounded,
                  size: iconSize - 4,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  const _ProfileItem({
    required this.index,
    required this.currentIndex,
    required this.onTap,
    required this.size,
    required this.animDuration,
    this.imageUrl,
  });

  final int index;
  final int currentIndex;
  final void Function(int) onTap;
  final double size;
  final Duration animDuration;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final isSelected = index == currentIndex;
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap(index);
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: AnimatedScale(
            scale: isSelected ? 1.08 : 1.0,
            duration: animDuration,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.35),
                  width: isSelected ? 2 : 1.5,
                ),
                color: hasImage ? null : Colors.white.withValues(alpha: 0.1),
                image: hasImage
                    ? DecorationImage(
                        image: NetworkImage(imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: hasImage
                  ? null
                  : Icon(
                      Icons.person_rounded,
                      size: size * 0.55,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.55),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
