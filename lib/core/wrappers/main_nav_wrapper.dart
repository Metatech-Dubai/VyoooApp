import 'package:flutter/material.dart';

import '../widgets/app_bottom_navigation.dart';
import '../../screens/home/home_reels_screen.dart';
import '../../screens/search/search_screen.dart';
import '../../screens/upload/upload_screen.dart';
import '../../screens/notifications/notification_screen.dart';
import '../../screens/profile/profile_screen.dart';

/// Main app shell: IndexedStack (0 Home, 1 Search, 2 Upload, 3 Notifications, 4 Profile) + single bottom nav.
/// Navigation is by index only; no push on tab tap. State persists per tab.
class MainNavWrapper extends StatefulWidget {
  const MainNavWrapper({super.key});

  @override
  State<MainNavWrapper> createState() => _MainNavWrapperState();
}

class _MainNavWrapperState extends State<MainNavWrapper> {
  int _currentIndex = 0;

  static const List<Widget> _screens = [
    HomeReelsScreen(),
    SearchScreen(),
    UploadScreen(),
    NotificationScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        profileImageUrl: null,
      ),
    );
  }
}
