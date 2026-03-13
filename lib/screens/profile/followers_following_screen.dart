import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../core/subscription/subscription_controller.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/subscription/subscription_screen.dart';
import 'user_profile_screen.dart';

/// Initial tab when opening the screen: 0 = Followers, 1 = Following, 2 = Subscriptions.
class FollowersFollowingScreen extends StatefulWidget {
  const FollowersFollowingScreen({
    super.key,
    this.initialTab = 0,
    this.followerCount = 1,
    this.followingCount = 10,
  });

  final int initialTab;
  final int followerCount;
  final int followingCount;

  @override
  State<FollowersFollowingScreen> createState() => _FollowersFollowingScreenState();
}

class _FollowersFollowingScreenState extends State<FollowersFollowingScreen> {
  late int _selectedTabIndex;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTab.clamp(0, 2);
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  void _showRemoveFollowerModal(BuildContext context, _ConnectionUser user) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                  Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16),
                    ),
                  ),
                  _RemoveModalButton(
                    label: 'Remove',
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Remove Follower?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage: Uri.tryParse(user.avatarUrl)?.isAbsolute == true
                    ? NetworkImage(user.avatarUrl)
                    : null,
                child: Uri.tryParse(user.avatarUrl)?.isAbsolute != true
                    ? Icon(Icons.person_rounded, size: 40, color: Colors.white.withValues(alpha: 0.6))
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                user.name,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  'We won\'t tell @${user.username} that they were removed from your followers.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  void _showRemoveFollowingModal(BuildContext context, _ConnectionUser user) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16),
                    ),
                  ),
                  _RemoveModalButton(
                    label: 'Remove',
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Remove from following?',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.lg),
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage: Uri.tryParse(user.avatarUrl)?.isAbsolute == true ? NetworkImage(user.avatarUrl) : null,
                child: Uri.tryParse(user.avatarUrl)?.isAbsolute != true
                    ? Icon(Icons.person_rounded, size: 40, color: Colors.white.withValues(alpha: 0.6))
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(user.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  'We won\'t tell @${user.username} that you stopped following them.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  void _showRemoveSubscriptionModal(BuildContext context, _ConnectionUser user) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16),
                    ),
                  ),
                  _RemoveModalButton(
                    label: 'Remove',
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Remove Subscription?',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.lg),
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage: Uri.tryParse(user.avatarUrl)?.isAbsolute == true ? NetworkImage(user.avatarUrl) : null,
                child: Uri.tryParse(user.avatarUrl)?.isAbsolute != true
                    ? Icon(Icons.person_rounded, size: 40, color: Colors.white.withValues(alpha: 0.6))
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(user.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  'We won\'t tell @${user.username} that you stopped subscribing them.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                    ),
                    Expanded(
                      child: uid != null
                          ? FutureBuilder<String>(
                              future: UserService().getUser(uid).then((u) =>
                                  u?.username?.isNotEmpty == true ? '@${u!.username}' : (AuthService().currentUser?.email ?? '@user')),
                              builder: (_, snap) => Text(
                                snap.data ?? '@lexilongbottom',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          : const Text(
                              '@lexilongbottom',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
                    ),
                  ],
                ),
              ),
              _buildTabs(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.input),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Search for users',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.6), size: 22),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _selectedTabIndex == 2
                    ? _buildSubscriptionsContent(context)
                    : _buildUserList(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    final followerLabel = widget.followerCount == 1 ? '1 Follower' : '${_formatCount(widget.followerCount)} Followers';
    final followingLabel = '${_formatCount(widget.followingCount)} Following';
    final labels = [followerLabel, followingLabel, 'Subscriptions'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: List.generate(3, (index) {
          final isSelected = index == _selectedTabIndex;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTabIndex = index),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      labels[index],
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: isSelected ? 1.0 : 0.7),
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSubscriptionsContent(BuildContext context) {
    final isSubscribed = context.watch<SubscriptionController>().isSubscriber ||
        context.watch<SubscriptionController>().isCreator;
    if (!isSubscribed) {
      return _buildBecomeMemberCard(context);
    }
    return _buildSubscriptionsList(context);
  }

  Widget _buildBecomeMemberCard(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.lg),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Want to Subscribe? Become a Member!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Subscribe today to access exclusive content from top creators. Enjoy a premium, seamless viewing experience wherever you are.',
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
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(FontAwesomeIcons.crown, size: 18, color: Colors.white.withValues(alpha: 0.95)),
                            const SizedBox(width: 10),
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
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionsList(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _mockSubscriptions
        : _mockSubscriptions.where((u) =>
            u.name.toLowerCase().contains(query) ||
            u.username.toLowerCase().contains(query)).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            'Recommended for you',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _recommendedUsers.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final u = _recommendedUsers[index];
              return GestureDetector(
                onTap: () {},
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      backgroundImage: NetworkImage(u.avatarUrl),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      u.name,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ...List.generate(filtered.length, (index) {
          final user = filtered[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _SubscriptionRow(
              user: user,
              onRemove: () => _showRemoveSubscriptionModal(context, user),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => UserProfileScreen(
                      payload: UserProfilePayload(
                        username: user.username,
                        displayName: user.name,
                        avatarUrl: user.avatarUrl,
                        isVerified: user.isVerified,
                        postCount: user.postCount,
                        followerCount: user.followerCount,
                        followingCount: user.followingCount,
                        bio: user.bio,
                        isCreator: user.isCreator,
                        isFollowing: true,
                        isSubscribed: true,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        }),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _buildUserList(BuildContext context) {
    final list = _selectedTabIndex == 0 ? _mockFollowers : _mockFollowing;
    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? list
        : list.where((u) =>
            u.name.toLowerCase().contains(query) ||
            u.username.toLowerCase().contains(query)).toList();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final user = filtered[index];
        return _ConnectionRow(
          user: user,
          isFollowing: _selectedTabIndex == 0 ? false : true,
          onRemove: () {
            if (_selectedTabIndex == 0) {
              _showRemoveFollowerModal(context, user);
            } else {
              _showRemoveFollowingModal(context, user);
            }
          },
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => UserProfileScreen(
                  payload: UserProfilePayload(
                    username: user.username,
                    displayName: user.name,
                    avatarUrl: user.avatarUrl,
                    isVerified: user.isVerified,
                    postCount: user.postCount,
                    followerCount: user.followerCount,
                    followingCount: user.followingCount,
                    bio: user.bio,
                    isCreator: user.isCreator,
                    isFollowing: _selectedTabIndex != 0,
                    isSubscribed: user.isSubscribed,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ConnectionUser {
  const _ConnectionUser({
    required this.name,
    required this.username,
    required this.avatarUrl,
    this.isVerified = false,
    this.postCount = 0,
    this.followerCount = 1,
    this.followingCount = 0,
    this.bio = '',
    this.isCreator = true,
    this.isSubscribed = false,
  });
  final String name;
  final String username;
  final String avatarUrl;
  final bool isVerified;
  final int postCount;
  final int followerCount;
  final int followingCount;
  final String bio;
  final bool isCreator;
  final bool isSubscribed;
}

final List<_ConnectionUser> _mockFollowers = [
  _ConnectionUser(name: 'Sofia Wells', username: 'sofwells3', avatarUrl: 'https://i.pravatar.cc/80?img=1'),
];

final List<_ConnectionUser> _mockFollowing = [
  _ConnectionUser(name: 'Josh Beauchamp', username: 'joshbeauchamp', avatarUrl: 'https://i.pravatar.cc/80?img=11', isVerified: true, postCount: 164, followerCount: 4400000, followingCount: 1224, bio: 'I just need a chance to prove', isCreator: true, isSubscribed: true),
  _ConnectionUser(name: 'Lexilongbottom', username: 'Lexilongbottom', avatarUrl: 'https://i.pravatar.cc/80?img=28', postCount: 0, followerCount: 1, followingCount: 10, isCreator: false),
  _ConnectionUser(name: 'Sofia Wells', username: 'sofwells3', avatarUrl: 'https://i.pravatar.cc/80?img=1'),
  _ConnectionUser(name: 'Liam Smith', username: 'liamsmith01', avatarUrl: 'https://i.pravatar.cc/80?img=2'),
  _ConnectionUser(name: 'Emma Johnson', username: 'emmaj', avatarUrl: 'https://i.pravatar.cc/80?img=3'),
  _ConnectionUser(name: 'Noah brown', username: 'noahb', avatarUrl: 'https://i.pravatar.cc/80?img=4'),
  _ConnectionUser(name: 'Olivia Davis', username: 'oliviad', avatarUrl: 'https://i.pravatar.cc/80?img=5'),
  _ConnectionUser(name: 'William Miller', username: 'willm', avatarUrl: 'https://i.pravatar.cc/80?img=6'),
  _ConnectionUser(name: 'Sophia Wilson', username: 'sophiaw', avatarUrl: 'https://i.pravatar.cc/80?img=7'),
  _ConnectionUser(name: 'James Anderson', username: 'jamesa', avatarUrl: 'https://i.pravatar.cc/80?img=8'),
  _ConnectionUser(name: 'Amelia Clark', username: 'ameliac', avatarUrl: 'https://i.pravatar.cc/80?img=9'),
  _ConnectionUser(name: 'Oliver lewis', username: 'oliverl', avatarUrl: 'https://i.pravatar.cc/80?img=10'),
];

/// Recommended users for Subscriptions tab (horizontal list).
class _RecommendedUser {
  const _RecommendedUser({required this.name, required this.avatarUrl});
  final String name;
  final String avatarUrl;
}

const List<_RecommendedUser> _recommendedUsers = [
  _RecommendedUser(name: 'Bob', avatarUrl: 'https://i.pravatar.cc/80?img=11'),
  _RecommendedUser(name: 'Alice', avatarUrl: 'https://i.pravatar.cc/80?img=22'),
  _RecommendedUser(name: 'Benjamin', avatarUrl: 'https://i.pravatar.cc/80?img=33'),
  _RecommendedUser(name: 'Clara', avatarUrl: 'https://i.pravatar.cc/80?img=24'),
  _RecommendedUser(name: 'Daniel', avatarUrl: 'https://i.pravatar.cc/80?img=15'),
  _RecommendedUser(name: 'Evelyn', avatarUrl: 'https://i.pravatar.cc/80?img=26'),
];

final List<_ConnectionUser> _mockSubscriptions = [
  _ConnectionUser(name: 'Sofia Wells', username: 'sofwells3', avatarUrl: 'https://i.pravatar.cc/80?img=1'),
  _ConnectionUser(name: 'Liam Smith', username: 'liamsmith01', avatarUrl: 'https://i.pravatar.cc/80?img=2'),
  _ConnectionUser(name: 'Emma Johnson', username: 'emmaj', avatarUrl: 'https://i.pravatar.cc/80?img=3'),
  _ConnectionUser(name: 'Noah brown', username: 'noahb', avatarUrl: 'https://i.pravatar.cc/80?img=4'),
  _ConnectionUser(name: 'Olivia Davis', username: 'oliviad', avatarUrl: 'https://i.pravatar.cc/80?img=5'),
  _ConnectionUser(name: 'William Miller', username: 'willm', avatarUrl: 'https://i.pravatar.cc/80?img=6'),
  _ConnectionUser(name: 'Sophia Wilson', username: 'sophiaw', avatarUrl: 'https://i.pravatar.cc/80?img=7'),
  _ConnectionUser(name: 'James Anderson', username: 'jamesa', avatarUrl: 'https://i.pravatar.cc/80?img=8'),
  _ConnectionUser(name: 'Issabell Thomas', username: 'issabellt', avatarUrl: 'https://i.pravatar.cc/80?img=9'),
];

class _ConnectionRow extends StatefulWidget {
  const _ConnectionRow({
    required this.user,
    required this.isFollowing,
    required this.onRemove,
    this.onTap,
  });

  final _ConnectionUser user;
  final bool isFollowing;
  final VoidCallback onRemove;
  final VoidCallback? onTap;

  @override
  State<_ConnectionRow> createState() => _ConnectionRowState();
}

class _ConnectionRowState extends State<_ConnectionRow> {
  late bool _isFollowing;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.isFollowing;
  }

  @override
  void didUpdateWidget(_ConnectionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFollowing != widget.isFollowing) _isFollowing = widget.isFollowing;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage: Uri.tryParse(widget.user.avatarUrl)?.isAbsolute == true
                    ? NetworkImage(widget.user.avatarUrl)
                    : null,
                child: Uri.tryParse(widget.user.avatarUrl)?.isAbsolute != true
                    ? Icon(Icons.person_rounded, color: Colors.white.withValues(alpha: 0.6))
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.user.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '@${widget.user.username}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _FollowingButton(
                isFollowing: _isFollowing,
                onTap: () {
                  if (_isFollowing) {
                    widget.onRemove();
                  } else {
                    setState(() => _isFollowing = true);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row for Subscriptions tab: avatar, name, handle, "Subscribed" badge with X.
class _SubscriptionRow extends StatelessWidget {
  const _SubscriptionRow({
    required this.user,
    required this.onRemove,
    required this.onTap,
  });

  final _ConnectionUser user;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage: Uri.tryParse(user.avatarUrl)?.isAbsolute == true
                    ? NetworkImage(user.avatarUrl)
                    : null,
                child: Uri.tryParse(user.avatarUrl)?.isAbsolute != true
                    ? Icon(Icons.person_rounded, color: Colors.white.withValues(alpha: 0.6))
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '@${user.username}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Material(
                color: const Color(0xFF2A1B2E),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: InkWell(
                  onTap: onRemove,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Subscribed',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.close, size: 14, color: Colors.white.withValues(alpha: 0.9)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pink gradient "Remove" button for confirmation modals.
class _RemoveModalButton extends StatelessWidget {
  const _RemoveModalButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFDE106B), Color(0xFFF81945)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FollowingButton extends StatelessWidget {
  const _FollowingButton({required this.isFollowing, required this.onTap});

  final bool isFollowing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (isFollowing) {
      return Material(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Following',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 6),
                Icon(Icons.close, size: 14, color: Colors.white.withValues(alpha: 0.9)),
              ],
            ),
          ),
        ),
      );
    }
    return Material(
      color: AppColors.pink,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Follow',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
