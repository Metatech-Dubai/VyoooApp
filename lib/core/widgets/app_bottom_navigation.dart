import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// Standard BottomNavigationBar wrapper.
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

  static const double _iconSize = 26;

  Widget _buildIcon(String asset, IconData fallback, bool isSelected) {
    return SizedBox(
      width: _iconSize,
      height: _iconSize,
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.55),
        colorBlendMode: BlendMode.modulate,
        errorBuilder: (ctx, err, stack) => Icon(
          fallback,
          size: _iconSize,
          color: isSelected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.55),
        ),
      ),
    );
  }

  Widget _buildProfileIcon(bool isSelected) {
    final hasImage = profileImageUrl != null && profileImageUrl!.isNotEmpty;
    return Container(
      width: _iconSize,
      height: _iconSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasImage ? null : Colors.white.withValues(alpha: 0.1),
        image: hasImage
            ? DecorationImage(
                image: NetworkImage(profileImageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: hasImage
          ? null
          : Icon(
              Icons.person_rounded,
              size: _iconSize * 0.55,
              color: isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.55),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF1B051D), // Dark purple/black
            Color(0xFF6B0E4C), // Deep magenta
            Color(0xFF8B125E), // Lighter magenta
          ],
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          HapticFeedback.lightImpact();
          onTap(index);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: [
          BottomNavigationBarItem(
            icon: _buildIcon(_NavAssets.homeUnselected, Icons.home_rounded, false),
            activeIcon: _buildIcon(_NavAssets.homeSelected, Icons.home_rounded, true),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: _buildIcon(_NavAssets.searchUnselected, Icons.search_rounded, false),
            activeIcon: _buildIcon(_NavAssets.searchSelected, Icons.search_rounded, true),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
              ),
              child: _buildIcon(_NavAssets.addUnselected, Icons.add, false),
            ),
            activeIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
              ),
              child: _buildIcon(_NavAssets.addSelected, Icons.add, true),
            ),
            label: 'Create',
          ),
          BottomNavigationBarItem(
            icon: _buildIcon(_NavAssets.notificationUnselected, Icons.notifications_none_rounded, false),
            activeIcon: _buildIcon(_NavAssets.notificationSelected, Icons.notifications_rounded, true),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: _buildProfileIcon(false),
            activeIcon: _buildProfileIcon(true),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
