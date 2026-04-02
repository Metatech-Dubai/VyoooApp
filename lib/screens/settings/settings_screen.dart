import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';


import '../../core/services/auth_service.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/wrappers/auth_wrapper.dart';
import '../account/account_screen.dart';

/// Settings screen for standard user: list with icons, PREMIUM tags, Logout in red.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14001F),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF3B0026),
              Color(0xFF14001F),
              Color(0xFF000000),
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAppBar(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.lg,
                  ),
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          _SettingsTile(
                            icon: Icons.person_outline_rounded,
                            label: 'Account',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const AccountScreen(),
                                ),
                              );
                            },
                          ),
                          _SettingsTile(
                            icon: FontAwesomeIcons.crown,
                            label: 'Subscriptions',
                            isPremium: true,
                            onTap: () {},
                          ),
                          _SettingsTile(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'VyooO Payout',
                            isPremium: true,
                            onTap: () {},
                          ),
                          _SettingsTile(
                            icon: Icons.download_rounded,
                            label: 'Downloaded Videos',
                            onTap: () {},
                          ),
                          _SettingsTile(
                            icon: Icons.notifications_none_rounded,
                            label: 'Notifications',
                            onTap: () {},
                          ),
                          _SettingsTile(
                            icon: Icons.headphones_outlined,
                            label: 'Contact Support',
                            onTap: () {},
                          ),
                          _SettingsTile(
                            icon: Icons.chat_bubble_outline_rounded,
                            label: 'Report Problem',
                            onTap: () {},
                          ),
                          _SettingsTile(
                            icon: Icons.info_outline_rounded,
                            label: 'About',
                            onTap: () {},
                          ),
                          const SizedBox(height: 8),
                          _SettingsTile(
                            icon: Icons.logout_rounded,
                            label: 'Logout',
                            isLogout: true,
                            onTap: () => _logout(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const Text(
            'Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const Text(
            'VyooO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
      (route) => false,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPremium = false,
    this.isLogout = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPremium;
  final bool isLogout;

  @override
  Widget build(BuildContext context) {
    final color = isLogout ? const Color(0xFFF81945) : Colors.white.withValues(alpha: 0.85);
    final labelColor = isLogout ? const Color(0xFFF81945) : Colors.white;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: color,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            if (isPremium) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFACC15),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFACC15).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'PREMIUM',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}
