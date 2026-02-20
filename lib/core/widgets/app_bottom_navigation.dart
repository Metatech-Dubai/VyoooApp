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

/// Custom bottom navigation. No BottomNavigationBar — gradient + overlay, parent controls index via onTap.
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

  static const double _height = 66; // 20% smaller (was 83)
  static const double _iconSize = 17; // +20% from 14
  static const double _profileSize = 23; // +20% from 19
  static const double _createButtonSize = 29; // +20% from 24
  static const Duration _animationDuration = Duration(milliseconds: 150);

  static const Color _selectedColor = Colors.white;
  static final Color _unselectedColor = Colors.white.withValues(alpha: 0.5);
  static final Color _createBorderColor = Colors.white.withValues(alpha: 0.6);
  static const Color _primaryPink = Color(0xFFDE106B);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _height,
      decoration: const BoxDecoration(
        gradient: AppGradients.feedGradient,
      ),
      child: SizedBox(
        height: _height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                Center(
              child: _NavIconItem(
                selectedAsset: _NavAssets.homeSelected,
                unselectedAsset: _NavAssets.homeUnselected,
                index: 0,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
            ),
            Center(
              child: _NavIconItem(
                selectedAsset: _NavAssets.searchSelected,
                unselectedAsset: _NavAssets.searchUnselected,
                index: 1,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
            ),
            Center(
              child: _CreateButton(
                onTap: () => onTap(2),
                isSelected: currentIndex == 2,
              ),
            ),
            Center(
              child: _NavIconItem(
                selectedAsset: _NavAssets.notificationSelected,
                unselectedAsset: _NavAssets.notificationUnselected,
                index: 3,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
            ),
                Center(
                  child: _ProfileNavItem(
                    index: 4,
                    currentIndex: currentIndex,
                    onTap: onTap,
                    imageUrl: profileImageUrl,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Nav item that displays custom asset icons (selected / unselected).
class _NavIconItem extends StatelessWidget {
  const _NavIconItem({
    required this.selectedAsset,
    required this.unselectedAsset,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  final String selectedAsset;
  final String unselectedAsset;
  final int index;
  final int currentIndex;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = index == currentIndex;
    final asset = isSelected ? selectedAsset : unselectedAsset;
    final isHome = index == 0;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap(index);
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: isSelected ? 1.1 : 1.0,
            duration: AppBottomNavigation._animationDuration,
            child: SizedBox(
              width: AppBottomNavigation._iconSize,
              height: AppBottomNavigation._iconSize,
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.circle_outlined,
                  size: AppBottomNavigation._iconSize,
                  color: isSelected
                      ? AppBottomNavigation._selectedColor
                      : AppBottomNavigation._unselectedColor,
                ),
              ),
            ),
          ),
          if (isHome && isSelected) ...[
            const SizedBox(height: 4),
            Container(
              width: 24,
              height: 3,
              decoration: BoxDecoration(
                color: AppBottomNavigation._primaryPink,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileNavItem extends StatelessWidget {
  const _ProfileNavItem({
    required this.index,
    required this.currentIndex,
    required this.onTap,
    this.imageUrl,
  });

  final int index;
  final int currentIndex;
  final void Function(int) onTap;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final isSelected = index == currentIndex;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap(index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: isSelected ? 1.1 : 1.0,
        duration: AppBottomNavigation._animationDuration,
        child: Container(
          width: AppBottomNavigation._profileSize,
          height: AppBottomNavigation._profileSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (imageUrl == null || imageUrl!.isEmpty)
                ? Colors.white.withValues(alpha: 0.08)
                : null,
            border: isSelected
                ? Border.all(color: Colors.white, width: 2)
                : null,
            image: (imageUrl != null && imageUrl!.isNotEmpty)
                ? DecorationImage(
                    image: NetworkImage(imageUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: (imageUrl == null || imageUrl!.isEmpty)
              ? Center(
                  child: Icon(
                    Icons.person_rounded,
                    size: AppBottomNavigation._iconSize,
                    color: isSelected
                        ? AppBottomNavigation._selectedColor
                        : AppBottomNavigation._unselectedColor,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({
    required this.onTap,
    required this.isSelected,
  });

  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final asset = isSelected
        ? _NavAssets.addSelected
        : _NavAssets.addUnselected;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: AppBottomNavigation._createButtonSize,
        height: AppBottomNavigation._createButtonSize,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppBottomNavigation._createBorderColor,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Image.asset(
            asset,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.add_rounded,
              size: AppBottomNavigation._iconSize,
              color: isSelected
                  ? AppBottomNavigation._primaryPink
                  : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
