import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/app_user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/reels_service.dart';
import '../../core/services/user_service.dart';
import '../../core/subscription/subscription_controller.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/wrappers/auth_wrapper.dart';
import '../../features/subscription/subscription_screen.dart';
import 'followers_following_screen.dart';
import '../settings/settings_screen.dart';

/// Own profile tab: header, stats, Edit Profile/Share, Posts/VR/Streams, empty or Become Member.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const List<String> _tabs = ['Posts', 'VR', 'Streams'];
  int _selectedTabIndex = 0;

  Future<void> _logout(BuildContext context) async {
    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
      (route) => false,
    );
  }

  Future<void> _showUploadStreamDialog(BuildContext context) async {
    final controller = TextEditingController();
    var markAsVR = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A0020),
          title: const Text(
            'Upload Stream videos',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste Cloudflare Stream video IDs (one per line or comma-separated):',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  maxLines: 6,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'abc123\ndef456\n...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                    border: const OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: markAsVR,
                  onChanged: (v) => setDialogState(() => markAsVR = v ?? false),
                  title: Text(
                    'Show in VR tab',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
                  ),
                  activeColor: const Color(0xFFDE106B),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
              ),
            ),
            FilledButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                final ids = text
                    .split(RegExp(r'[\n,;]+'))
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                if (ids.isEmpty) return;
                final messenger = ScaffoldMessenger.of(context);
                Navigator.of(ctx).pop();
                try {
                  final added = await ReelsService().seedStreamReels(ids, markAsVR: markAsVR);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Uploaded $added reel(s) to Firebase.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Upload failed: $e'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDE106B),
                foregroundColor: Colors.white,
              ),
              child: const Text('Upload to Firebase'),
            ),
          ],
        ),
      ),
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

  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF2A1B2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.settings_rounded, color: Colors.white.withValues(alpha: 0.8)),
              title: Text(
                'Settings',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.upload_rounded, color: Colors.white.withValues(alpha: 0.8)),
              title: Text(
                'Upload Stream videos',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showUploadStreamDialog(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.logout_rounded, color: Colors.white.withValues(alpha: 0.8)),
              title: Text(
                'Log out',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _logout(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_forever_rounded, color: Colors.red.withValues(alpha: 0.9)),
              title: const Text(
                'Delete account',
                style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _requestAccountDeletion(context);
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final uid = AuthService().currentUser?.uid;
    final hasAccess = context.watch<SubscriptionController>().hasAccess;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF14001F),
              Color(0xFF4A003F),
              Color(0xFFDE106B),
            ],
          ),
        ),
        child: SafeArea(
          child: uid == null
              ? _buildFallbackProfile(context)
              : FutureBuilder<AppUserModel?>(
                  future: UserService().getUser(uid),
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    return _buildProfileBody(context, user: user, hasAccess: hasAccess);
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildFallbackProfile(BuildContext context) {
    return _buildProfileBody(
      context,
      user: null,
      hasAccess: context.watch<SubscriptionController>().hasAccess,
    );
  }

  Widget _buildProfileBody(BuildContext context, {AppUserModel? user, required bool hasAccess}) {
    final username = user?.username?.isNotEmpty == true
        ? '@${user!.username}'
        : (AuthService().currentUser?.email ?? 'Profile');
    final displayName = user?.username?.isNotEmpty == true ? user!.username! : 'Name +';
    final avatarUrl = user?.profileImage;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const SizedBox(width: 40),
                    Expanded(
                      child: Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showProfileMenu(context),
                      icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                CircleAvatar(
                  radius: 52,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? Icon(Icons.person_rounded, size: 52, color: Colors.white.withValues(alpha: 0.6))
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StatChip(label: 'POSTS', value: '0'),
                    const SizedBox(width: AppSpacing.sm),
                    _StatChip(
                      label: 'FOLLOWERS',
                      value: '1',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const FollowersFollowingScreen(
                            initialTab: 0,
                            followerCount: 1,
                            followingCount: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _StatChip(
                      label: 'FOLLOWING',
                      value: '10',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const FollowersFollowingScreen(
                            initialTab: 1,
                            followerCount: 1,
                            followingCount: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: _PinkButton(label: 'Edit Profile', onPressed: () {}),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _GreenButton(label: 'Share', onPressed: () {}),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                _buildTabs(),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: _selectedTabIndex == 0
              ? (hasAccess ? _buildEmptyPostsPrompt() : _buildBecomeMemberPrompt(context))
              : _buildEmptyTabPlaceholder(),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Row(
      children: List.generate(_tabs.length, (index) {
        final isSelected = index == _selectedTabIndex;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < _tabs.length - 1 ? AppSpacing.xs : 0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedTabIndex = index),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0xFFDE106B), Color(0xFFF81945)],
                          )
                        : null,
                    color: isSelected ? null : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Center(
                    child: Text(
                      _tabs[index],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildEmptyPostsPrompt() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 80,
            color: Colors.white.withValues(alpha: 0.4),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Tap the "+" button below to post!',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBecomeMemberPrompt(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Ready to post? Become a Member!',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Become our member to start posting your content. Unlock full access and showcase your creativity today and you can also "monetize your content"',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFFE8C547), Color(0xFFD4A84B), Color(0xFFB8862E)],
              ),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SubscriptionScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FontAwesomeIcons.dollarSign, size: 16, color: Colors.white.withValues(alpha: 0.95)),
                      const SizedBox(width: 8),
                      const Text(
                        'Become Member',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTabPlaceholder() {
    return Center(
      child: Text(
        'No content yet',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinkButton extends StatelessWidget {
  const _PinkButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.pink,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _GreenButton extends StatelessWidget {
  const _GreenButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.whatsappGreen,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.share_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
