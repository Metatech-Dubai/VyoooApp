import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../constants/profile_assets.dart';
import '../../theme/app_spacing.dart';
import '../../../screens/profile/profile_figma_tokens.dart';

/// Profile overflow menu — slides in from the right (Figma “More” drawer).
Future<void> showProfileMoreDrawer(
  BuildContext context, {
  required VoidCallback onVyrooAi,
  required VoidCallback onMarketplace,
  required VoidCallback onWallet,
  required VoidCallback onVyoooCoin,
  required VoidCallback onOrders,
  required VoidCallback onSettings,
  required VoidCallback onSwitchAccounts,
  required VoidCallback onPrivacy,
  required VoidCallback onLogout,
  VoidCallback? onRevenue,
}) {
  final screenWidth = MediaQuery.sizeOf(context).width;
  final drawerWidth = math.min(
    ProfileFigmaTokens.profileMoreDrawerWidth,
    screenWidth,
  );

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss profile menu',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: ProfileFigmaTokens.profileMoreDrawerAnimation,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: drawerWidth,
            child: ProfileMoreDrawer(
              drawerWidth: drawerWidth,
              onVyrooAi: () {
                Navigator.pop(dialogContext);
                onVyrooAi();
              },
              onMarketplace: () {
                Navigator.pop(dialogContext);
                onMarketplace();
              },
              onWallet: () {
                Navigator.pop(dialogContext);
                onWallet();
              },
              onVyoooCoin: () {
                Navigator.pop(dialogContext);
                onVyoooCoin();
              },
              onRevenue: onRevenue,
              onOrders: () {
                Navigator.pop(dialogContext);
                onOrders();
              },
              onSettings: () {
                Navigator.pop(dialogContext);
                onSettings();
              },
              onSwitchAccounts: () {
                Navigator.pop(dialogContext);
                onSwitchAccounts();
              },
              onPrivacy: () {
                Navigator.pop(dialogContext);
                onPrivacy();
              },
              onLogout: () {
                Navigator.pop(dialogContext);
                onLogout();
              },
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

/// Figma 341×704 tap rows — coordinates match [profile_more_drawer_panel.svg]
/// after Creator Tools (Music library / Upload Stream) removal.
typedef _MoreDrawerTapRow = ({
  double top,
  double height,
  double horizontalInset,
  double? width,
  VoidCallback onTap,
});

class ProfileMoreDrawer extends StatelessWidget {
  const ProfileMoreDrawer({
    super.key,
    required this.drawerWidth,
    required this.onVyrooAi,
    required this.onMarketplace,
    required this.onWallet,
    required this.onVyoooCoin,
    this.onRevenue,
    required this.onOrders,
    required this.onSettings,
    required this.onSwitchAccounts,
    required this.onPrivacy,
    required this.onLogout,
  });

  /// Full drawer shell width — never shrunk for height fitting.
  final double drawerWidth;

  final VoidCallback onVyrooAi;
  final VoidCallback onMarketplace;
  final VoidCallback onWallet;
  final VoidCallback onVyoooCoin;
  final VoidCallback? onRevenue;
  final VoidCallback onOrders;
  final VoidCallback onSettings;
  final VoidCallback onSwitchAccounts;
  final VoidCallback onPrivacy;
  final VoidCallback onLogout;

  static const _designWidth = ProfileFigmaTokens.profileMoreDrawerWidth;
  static const _designHeight = ProfileFigmaTokens.profileMoreDrawerDesignHeight;
  static const _contentInset =
      ProfileFigmaTokens.profileMoreDrawerContentHorizontalInset;
  static const _contentWidth = ProfileFigmaTokens.profileMoreDrawerContentWidth;

  List<_MoreDrawerTapRow> get _tapRows => [
        (
          top: 76,
          height: 52,
          horizontalInset: _contentInset,
          width: _contentWidth,
          onTap: onVyrooAi,
        ),
        (
          top: 128,
          height: 52,
          horizontalInset: _contentInset,
          width: _contentWidth,
          onTap: onMarketplace,
        ),
        (
          top: 180,
          height: 52,
          horizontalInset: _contentInset,
          width: _contentWidth,
          onTap: onVyoooCoin,
        ),
        (
          top: 232,
          height: 52,
          horizontalInset: _contentInset,
          width: _contentWidth,
          onTap: onRevenue ?? onWallet,
        ),
        (
          top: 350,
          height: 52,
          horizontalInset: _contentInset,
          width: _contentWidth,
          onTap: onSwitchAccounts,
        ),
        (
          top: 402,
          height: 52,
          horizontalInset: _contentInset,
          width: _contentWidth,
          onTap: onSettings,
        ),
        (
          top: 454,
          height: 52,
          horizontalInset: _contentInset,
          width: _contentWidth,
          onTap: onPrivacy,
        ),
        (
          top: 513.5,
          height: 57,
          horizontalInset:
              ProfileFigmaTokens.profileMoreDrawerLogoutHorizontalInset,
          width: ProfileFigmaTokens.profileMoreDrawerLogoutWidth,
          onTap: onLogout,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    // Width stays at Figma proportion — only height may overflow → scroll.
    final scale = drawerWidth / _designWidth;
    final panelHeight = _designHeight * scale;

    final panel = SizedBox(
      width: drawerWidth,
      height: panelHeight,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: SvgPicture.asset(
              ProfileAssets.profileMoreDrawerPanel,
              fit: BoxFit.fill,
            ),
          ),
          for (final row in _tapRows)
            Positioned(
              top: row.top * scale,
              left: row.horizontalInset * scale,
              width: (row.width ?? _contentWidth) * scale,
              height: row.height * scale,
              child: _ProfileMoreDrawerTapTarget(onTap: row.onTap),
            ),
        ],
      ),
    );

    return Material(
      color: Colors.white,
      child: SizedBox(
        width: drawerWidth,
        height: double.infinity,
        child: SafeArea(
          left: false,
          right: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final needsScroll =
                  panelHeight > constraints.maxHeight + 0.5;
              if (!needsScroll) {
                return panel;
              }
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: panel,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileMoreDrawerTapTarget extends StatelessWidget {
  const _ProfileMoreDrawerTapTarget({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap),
    );
  }
}
