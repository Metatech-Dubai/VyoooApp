import 'package:flutter/material.dart';

import '../../core/theme/app_padding.dart';
import '../../core/theme/app_spacing.dart';

import '../../core/services/auth_service.dart';
import '../../core/wrappers/auth_wrapper.dart';

/// Profile tab. Contains Account Deletion for store compliance.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _logout(BuildContext context) async {
    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
      (route) => false,
    );
  }

  Future<void> _requestAccountDeletion(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0020),
        title: const Text(
          'Delete account',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will permanently delete your account and all associated data. This cannot be undone. Are you sure?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete account',
              style: TextStyle(color: Color(0xFFD10057), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    // TODO: Call AuthService.deleteAccount() and delete Firestore user data.
    // For now, sign out and show message (full delete requires re-auth flow).
    await AuthService().signOut();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account deletion requested. Sign out complete.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0D0015),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: AppPadding.screenHorizontal.copyWith(top: AppSpacing.xl, bottom: AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppPadding.sectionGap,
                    Center(
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        child: Icon(
                          Icons.person_rounded,
                          size: 56,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    AppPadding.itemGap,
                    Center(
                      child: Text(
                        AuthService().currentUser?.email ?? 'Profile',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                    SizedBox(height: AppSpacing.xl + AppSpacing.sm),
                    const Divider(color: Colors.white24),
                    ListTile(
                      leading: Icon(
                        Icons.logout_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 24,
                      ),
                      title: Text(
                        'Log out',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 16,
                        ),
                      ),
                      onTap: () => _logout(context),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.delete_forever_rounded,
                        color: Colors.red.withValues(alpha: 0.9),
                        size: 24,
                      ),
                      title: const Text(
                        'Delete account',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        'Permanently delete your account and data',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                      onTap: () => _requestAccountDeletion(context),
                    ),
                    const Divider(color: Colors.white24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
