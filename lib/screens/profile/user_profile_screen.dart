import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_gradient_background.dart';

/// Data for displaying another user's profile (e.g. from search).
class UserProfilePayload {
  const UserProfilePayload({
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    this.isVerified = false,
    this.postCount = 0,
    required this.followerCount,
    this.followingCount = 0,
    this.bio = '',
  });

  final String username;
  final String displayName;
  final String avatarUrl;
  final bool isVerified;
  final int postCount;
  final int followerCount;
  final int followingCount;
  final String bio;
}

/// Other person's profile: header, stats, Follow/Subscribe/Share, Posts/VR/Streams, grid.
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.payload});

  final UserProfilePayload payload;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  static const List<String> _tabs = ['Posts', 'VR', 'Streams'];
  int _selectedTabIndex = 0;

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payload;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType.profile,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
              ),
              title: Text(
                '@${p.username}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              centerTitle: false,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      backgroundImage: Uri.tryParse(p.avatarUrl)?.isAbsolute == true
                          ? NetworkImage(p.avatarUrl)
                          : null,
                      child: Uri.tryParse(p.avatarUrl)?.isAbsolute != true
                          ? Icon(Icons.person_rounded, size: 52, color: Colors.white.withValues(alpha: 0.6))
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          p.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (p.isVerified) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.check_circle_rounded, size: 20, color: AppColors.deleteRed),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _StatChip(label: 'POSTS', value: _formatCount(p.postCount)),
                        const SizedBox(width: AppSpacing.sm),
                        _StatChip(label: 'FOLLOWERS', value: _formatCount(p.followerCount)),
                        const SizedBox(width: AppSpacing.sm),
                        _StatChip(label: 'FOLLOWING', value: _formatCount(p.followingCount)),
                      ],
                    ),
                    if (p.bio.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        p.bio,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: _PinkButton(
                            label: 'Follow',
                            onPressed: () {},
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _GradientButton(
                            label: 'Subscribe',
                            icon: FontAwesomeIcons.dollarSign,
                            onPressed: () {},
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Material(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.share_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _buildTabs(),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
            if (_selectedTabIndex == 0)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.85,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _GridThumbnail(
                      imageUrl: 'https://picsum.photos/400/480?random=${p.username}$index',
                    ),
                    childCount: 12,
                  ),
                ),
              )
            else
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'No ${_tabs[_selectedTabIndex]} content yet',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          ],
        ),
      ),
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
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
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

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.95)),
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
      ),
    );
  }
}

class _GridThumbnail extends StatelessWidget {
  const _GridThumbnail({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: Image.network(imageUrl, fit: BoxFit.cover),
    );
  }
}
