import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/app_user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../core/utils/user_facing_errors.dart';
import '../../core/subscription/subscription_controller.dart';
import '../../core/theme/app_light_surface.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../features/subscription/subscription_screen.dart';
import 'user_profile_screen.dart';

/// Initial tab when opening the screen: 0 = Followers, 1 = Following, 2 = Subscriptions.
/// [profileUserId]: whose lists to load; omit to use the signed-in user (own profile).
class FollowersFollowingScreen extends StatefulWidget {
  const FollowersFollowingScreen({
    super.key,
    this.initialTab = 0,
    this.profileUserId,
  });

  final int initialTab;

  /// Firestore uid for the profile whose followers/following are listed.
  final String? profileUserId;

  @override
  State<FollowersFollowingScreen> createState() =>
      _FollowersFollowingScreenState();
}

class _FollowersFollowingScreenState extends State<FollowersFollowingScreen> {
  late int _selectedTabIndex;
  final TextEditingController _searchController = TextEditingController();

  bool _loadingLists = true;
  int _followerCount = 0;
  int _followingCount = 0;
  List<_ConnectionUser> _followers = [];
  List<_ConnectionUser> _following = [];
  List<_ConnectionUser> _discoverUsers = [];

  /// When non-null, this profile's connections are hidden (private / personal, viewer not following).
  String? _privateConnectionsGate;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTab.clamp(0, 2);
    _searchController.addListener(() => setState(() {}));
    _loadConnections();
    // Reconcile store status on entry so paid members don't momentarily see
    // upsell UI due to delayed sandbox/store sync.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = AuthService().currentUser?.uid;
      context.read<SubscriptionController>().reconcilePaidStatus(
        firebaseUid: uid,
      );
    });
  }

  @override
  void didUpdateWidget(FollowersFollowingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileUserId != widget.profileUserId) {
      _loadConnections();
    }
  }

  /// When non-null, hide lists (private/personal profile, viewer not an accepted follower).
  Future<({String message, int followerCount, int followingCount})?>
      _connectionsPrivacyGate(String subject, UserService svc) async {
    final me = (AuthService().currentUser?.uid ?? '').trim();
    if (me.isNotEmpty && me == subject) return null;

    final target = await svc.getUser(subject);
    if (target == null) return null;
    if (!UserService.accountTypeRequiresFollowApproval(target.accountType)) {
      return null;
    }
    if (me.isEmpty) {
      return (
        message:
            'Sign in and follow this account to see followers and following.',
        followerCount: target.followersCount,
        followingCount: target.following.length,
      );
    }
    final follows =
        await svc.isFollowingUser(currentUid: me, targetUid: subject);
    if (follows) return null;
    return (
      message: 'Follow this account to see their followers and following.',
      followerCount: target.followersCount,
      followingCount: target.following.length,
    );
  }

  Future<void> _loadConnections() async {
    final subject = widget.profileUserId ?? AuthService().currentUser?.uid;
    if (subject == null || subject.isEmpty) {
      if (mounted) {
        setState(() {
          _loadingLists = false;
          _privateConnectionsGate = null;
          _followers = [];
          _following = [];
          _followerCount = 0;
          _followingCount = 0;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loadingLists = true;
        _privateConnectionsGate = null;
      });
    }

    final svc = UserService();
    final gate = await _connectionsPrivacyGate(subject, svc);
    if (gate != null) {
      if (!mounted) return;
      setState(() {
        _loadingLists = false;
        _privateConnectionsGate = gate.message;
        _followerCount = gate.followerCount;
        _followingCount = gate.followingCount;
        _followers = [];
        _following = [];
        _discoverUsers = [];
      });
      return;
    }

    final me = AuthService().currentUser?.uid;
    var myFollowing = <String>[];
    var myBlocked = <String>[];
    if (me != null && me.isNotEmpty) {
      myFollowing = await svc.getFollowing(me);
      myBlocked = await svc.getBlockedUserIds(me);
    }
    final blockedSet = myBlocked.toSet();

    final followerModels = await svc.getFollowerProfilesForUser(subject);
    final followingModels = await svc.getFollowingProfilesForUser(subject);
    final fc = await svc.getFollowerCount(subject);
    final discoverItems = me == null || me.isEmpty
        ? <UserDiscoveryItem>[]
        : await svc.discoverUserItems(currentUid: me, limit: 160);
    final discover = discoverItems
        .map(
          (i) => _ConnectionUser(
            targetUserId: i.uid,
            name: i.displayName,
            username: i.username,
            avatarUrl: i.avatarUrl,
            isVerified: i.isVerified,
            accountType: i.accountType,
            vipVerified: i.vipVerified,
            monetizationEnabled: i.monetizationEnabled,
            isFollowing: i.isFollowing,
            pendingFollowRequest: i.outgoingFollowRequestPending,
          ),
        )
        .toList();

    var followers = followerModels
        .where((m) => !blockedSet.contains(m.uid))
        .map((m) => _connectionFromAppUser(m, myFollowing))
        .toList();
    var following = followingModels
        .where((m) => !blockedSet.contains(m.uid))
        .map((m) => _connectionFromAppUser(m, myFollowing))
        .toList();
    if (me != null && me.isNotEmpty) {
      followers = await _enrichPendingFollowRequests(followers, me, svc);
      following = await _enrichPendingFollowRequests(following, me, svc);
    }

    if (!mounted) return;
    setState(() {
      _loadingLists = false;
      _privateConnectionsGate = null;
      _followerCount = fc;
      _followingCount = followingModels.length;
      _followers = followers;
      _following = following;
      _discoverUsers = discover;
    });
  }

  Future<List<_ConnectionUser>> _enrichPendingFollowRequests(
    List<_ConnectionUser> connections,
    String me,
    UserService svc,
  ) async {
    final pendingChecks = <Future<void>>[];
    final pendingByUid = <String, bool>{};
    for (final c in connections) {
      final id = c.targetUserId;
      if (id == null || id.isEmpty || c.isFollowing) continue;
      if (!UserService.accountTypeRequiresFollowApproval(c.accountType)) {
        continue;
      }
      pendingChecks.add(
        svc
            .outgoingFollowRequestPending(requesterUid: me, targetUid: id)
            .then((p) => pendingByUid[id] = p),
      );
    }
    if (pendingChecks.isEmpty) return connections;
    await Future.wait(pendingChecks);
    return connections
        .map((c) {
          final id = c.targetUserId;
          if (id == null || c.isFollowing) return c;
          final pending = pendingByUid[id] ?? false;
          if (!pending) return c;
          return c.copyWith(pendingFollowRequest: true);
        })
        .toList();
  }

  void _patchConnectionUser(
    String targetUserId, {
    required bool isFollowing,
    required bool pendingFollowRequest,
  }) {
    if (!mounted) return;
    setState(() {
      _followers = _followers
          .map(
            (u) => u.targetUserId == targetUserId
                ? u.copyWith(
                    isFollowing: isFollowing,
                    pendingFollowRequest: pendingFollowRequest,
                  )
                : u,
          )
          .toList();
      _following = _following
          .map(
            (u) => u.targetUserId == targetUserId
                ? u.copyWith(
                    isFollowing: isFollowing,
                    pendingFollowRequest: pendingFollowRequest,
                  )
                : u,
          )
          .toList();
      _discoverUsers = _discoverUsers
          .map(
            (u) => u.targetUserId == targetUserId
                ? u.copyWith(
                    isFollowing: isFollowing,
                    pendingFollowRequest: pendingFollowRequest,
                  )
                : u,
          )
          .toList();
    });
  }

  Future<void> _onConnectionFollowButtonTap(_ConnectionUser user) async {
    final me = AuthService().currentUser?.uid;
    final id = user.targetUserId;
    if (me == null || me.isEmpty || id == null || id.isEmpty || me == id) {
      return;
    }

    if (user.isFollowing) {
      _showRemoveFollowingModal(context, user);
      return;
    }

    final svc = UserService();
    try {
      if (user.pendingFollowRequest) {
        await svc.cancelFollowRequest(requesterUid: me, targetUid: id);
      } else {
        await svc.followUser(currentUid: me, targetUid: id);
      }
      final nowFollowing = await svc.isFollowingUser(
        currentUid: me,
        targetUid: id,
        server: true,
      );
      final nextPending = nowFollowing
          ? false
          : await svc.outgoingFollowRequestPending(
              requesterUid: me,
              targetUid: id,
              server: true,
            );
      _patchConnectionUser(
        id,
        isFollowing: nowFollowing,
        pendingFollowRequest: nextPending,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageForFirestore(e))),
        );
      }
    }
  }

  static _ConnectionUser _connectionFromAppUser(
    AppUserModel m,
    List<String> myFollowing,
  ) {
    final handle = (m.username != null && m.username!.trim().isNotEmpty)
        ? m.username!.trim()
        : (m.email.contains('@')
              ? m.email.split('@').first
              : (m.uid.length > 8 ? m.uid.substring(0, 8) : m.uid));
    final displayName =
        (m.displayName != null && m.displayName!.trim().isNotEmpty)
        ? m.displayName!.trim()
        : handle;
    return _ConnectionUser(
      targetUserId: m.uid,
      name: displayName,
      username: handle,
      avatarUrl: m.profileImage ?? '',
      isVerified: m.isVerified,
      accountType: m.accountType,
      vipVerified: m.vipVerified,
      monetizationEnabled: m.monetizationEnabled,
      isFollowing: myFollowing.contains(m.uid),
    );
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
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppBottomSheet.shell(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBottomSheet.dragHandle(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppLightSurface.secondaryText,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _RemoveModalButton(
                    label: 'Remove',
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      final target = user.targetUserId;
                      final me = AuthService().currentUser?.uid;
                      if (target == null ||
                          target.isEmpty ||
                          me == null ||
                          me.isEmpty) {
                        return;
                      }
                      try {
                        await UserService().removeFollower(
                          currentUid: me,
                          followerUid: target,
                        );
                        if (context.mounted) {
                          await _loadConnections();
                          messenger.showSnackBar(
                            const SnackBar(
                                content: Text('Follower removed.')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(messageForFirestore(e))),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Remove this follower?',
                style: TextStyle(
                  color: AppLightSurface.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              CircleAvatar(
                radius: 40,
                backgroundColor: AppLightSurface.cardFill,
                backgroundImage:
                    Uri.tryParse(user.avatarUrl)?.isAbsolute == true
                    ? NetworkImage(user.avatarUrl)
                    : null,
                child: Uri.tryParse(user.avatarUrl)?.isAbsolute != true
                    ? Icon(
                        Icons.person_rounded,
                        size: 40,
                        color: AppLightSurface.mutedText,
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                user.name,
                style: TextStyle(
                  color: AppLightSurface.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  'This account will be removed from your followers. They won\'t be notified that you removed them.',
                  style: TextStyle(
                    color: AppLightSurface.secondaryText,
                    fontSize: 14,
                  ),
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
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppBottomSheet.shell(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBottomSheet.dragHandle(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppLightSurface.secondaryText,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _RemoveModalButton(
                    label: 'Unfollow',
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final id = user.targetUserId;
                      final me = AuthService().currentUser?.uid;
                      if (id == null ||
                          id.isEmpty ||
                          me == null ||
                          me.isEmpty) {
                        return;
                      }
                      try {
                        await UserService().unfollowUser(
                          currentUid: me,
                          targetUid: id,
                        );
                        if (context.mounted) {
                          _patchConnectionUser(
                            id,
                            isFollowing: false,
                            pendingFollowRequest: false,
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(messageForFirestore(e))),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Remove from following?',
                style: TextStyle(
                  color: AppLightSurface.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              CircleAvatar(
                radius: 40,
                backgroundColor: AppLightSurface.cardFill,
                backgroundImage:
                    Uri.tryParse(user.avatarUrl)?.isAbsolute == true
                    ? NetworkImage(user.avatarUrl)
                    : null,
                child: Uri.tryParse(user.avatarUrl)?.isAbsolute != true
                    ? Icon(
                        Icons.person_rounded,
                        size: 40,
                        color: AppLightSurface.mutedText,
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                user.name,
                style: TextStyle(
                  color: AppLightSurface.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  'We won\'t tell @${user.username} that you stopped following them.',
                  style: TextStyle(
                    color: AppLightSurface.secondaryText,
                    fontSize: 14,
                  ),
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

  void _showRemoveSubscriptionModal(
    BuildContext context,
    _ConnectionUser user,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppBottomSheet.shell(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBottomSheet.dragHandle(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppLightSurface.secondaryText,
                        fontSize: 16,
                      ),
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
                style: TextStyle(
                  color: AppLightSurface.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              CircleAvatar(
                radius: 40,
                backgroundColor: AppLightSurface.cardFill,
                backgroundImage:
                    Uri.tryParse(user.avatarUrl)?.isAbsolute == true
                    ? NetworkImage(user.avatarUrl)
                    : null,
                child: Uri.tryParse(user.avatarUrl)?.isAbsolute != true
                    ? Icon(
                        Icons.person_rounded,
                        size: 40,
                        color: AppLightSurface.mutedText,
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                user.name,
                style: TextStyle(
                  color: AppLightSurface.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  'We won\'t tell @${user.username} that you stopped subscribing them.',
                  style: TextStyle(
                    color: AppLightSurface.secondaryText,
                    fontSize: 14,
                  ),
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
      backgroundColor: AppLightSurface.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppLightSurface.icon,
                      size: 22,
                    ),
                  ),
                  Expanded(
                    child: uid != null
                        ? FutureBuilder<String>(
                            future: UserService()
                                .getUser(uid)
                                .then(
                                  (u) => u?.username?.isNotEmpty == true
                                      ? '@${u!.username}'
                                      : (AuthService().currentUser?.email ??
                                            '@user'),
                                ),
                            builder: (_, snap) => Text(
                              snap.data ?? '@lexilongbottom',
                              style: TextStyle(
                                color: AppLightSurface.primaryText,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        : Text(
                            '@lexilongbottom',
                            style: TextStyle(
                              color: AppLightSurface.primaryText,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(
                      Icons.menu_rounded,
                      color: AppLightSurface.icon,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
            _buildTabs(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppLightSurface.cardFill,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  border: Border.all(color: AppLightSurface.border),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(
                    color: AppLightSurface.primaryText,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search for users',
                    hintStyle: TextStyle(
                      color: AppLightSurface.secondaryText,
                      fontSize: 16,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppLightSurface.mutedText,
                      size: 22,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 12,
                    ),
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
    );
  }

  Widget _buildTabs() {
    final followerLabel = _followerCount == 1
        ? '1 Follower'
        : '${_formatCount(_followerCount)} Followers';
    final followingLabel = '${_formatCount(_followingCount)} Following';
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
                        color: isSelected
                            ? AppLightSurface.primaryText
                            : AppLightSurface.secondaryText,
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.brandPink
                          : Colors.transparent,
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
    final isSubscribed = context.watch<SubscriptionController>().isPaid;
    if (!isSubscribed) {
      return _buildBecomeMemberCard(context);
    }
    return _buildSubscriptionsList(context);
  }

  Widget _buildBecomeMemberCard(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppLightSurface.cardFill,
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(color: AppLightSurface.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Want to Subscribe? Become a Member!',
                  style: TextStyle(
                    color: AppLightSurface.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Subscribe today to access exclusive content from top creators. Enjoy a premium, seamless viewing experience wherever you are.',
                  style: TextStyle(
                    color: AppLightSurface.secondaryText,
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
                      colors: [
                        Color(0xFFE8C547),
                        Color(0xFFD4A84B),
                        Color(0xFFB8862E),
                      ],
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FaIcon(
                              FontAwesomeIcons.crown,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
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
    final recommended = _discoverUsers
        .where((u) => !u.isFollowing)
        .take(10)
        .toList();
    final filtered = query.isEmpty
        ? _discoverUsers
        : _discoverUsers
              .where(
                (u) =>
                    u.name.toLowerCase().contains(query) ||
                    u.username.toLowerCase().contains(query),
              )
              .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            'Recommended for you',
            style: TextStyle(
              color: AppLightSurface.primaryText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recommended.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final u = recommended[index];
              return GestureDetector(
                onTap: () {},
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppLightSurface.cardFill,
                      backgroundImage: u.avatarUrl.isNotEmpty
                          ? NetworkImage(u.avatarUrl)
                          : null,
                      child: u.avatarUrl.isEmpty
                          ? Icon(
                              Icons.person_rounded,
                              color: AppLightSurface.mutedText,
                            )
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      u.name,
                      style: TextStyle(
                        color: AppLightSurface.secondaryText,
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
                        accountType: user.accountType,
                        vipVerified: user.vipVerified,
                        monetizationEnabled: user.monetizationEnabled,
                        postCount: 0,
                        followerCount: 0,
                        followingCount: 0,
                        bio: '',
                        isFollowing: user.isFollowing,
                        isSubscribed: true,
                        targetUserId: user.targetUserId,
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
    if (_loadingLists) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.brandPink),
      );
    }

    if (_privateConnectionsGate != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 48,
                color: AppLightSurface.mutedText,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _privateConnectionsGate!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppLightSurface.secondaryText,
                  fontSize: 16,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final query = _searchController.text.trim().toLowerCase();
    final baseList = query.isEmpty
        ? (_selectedTabIndex == 0 ? _followers : _following)
        : _discoverUsers;
    final filtered = query.isEmpty
        ? baseList
        : baseList
              .where(
                (u) =>
                    u.name.toLowerCase().contains(query) ||
                    u.username.toLowerCase().contains(query),
              )
              .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            query.isNotEmpty
                ? 'No users found.'
                : (_selectedTabIndex == 0
                      ? 'No followers yet.'
                      : 'Not following anyone yet.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppLightSurface.secondaryText,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    final me = AuthService().currentUser?.uid;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      itemCount: filtered.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final user = filtered[index];
        final id = user.targetUserId;
        return _ConnectionRow(
          user: user,
          isFollowing: user.isFollowing,
          pendingFollowRequest: user.pendingFollowRequest,
          onFollowTap: (me != null && id != null && id.isNotEmpty && me != id)
              ? () => _onConnectionFollowButtonTap(user)
              : null,
          onTap: id == null || id.isEmpty
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => UserProfileScreen(
                        payload: UserProfilePayload(
                          username: user.username,
                          displayName: user.name,
                          avatarUrl: user.avatarUrl,
                          isVerified: user.isVerified,
                          accountType: user.accountType,
                          vipVerified: user.vipVerified,
                          monetizationEnabled: user.monetizationEnabled,
                          postCount: 0,
                          followerCount: 0,
                          followingCount: 0,
                          bio: '',
                          isFollowing: user.isFollowing,
                          isSubscribed: false,
                          targetUserId: id,
                        ),
                      ),
                    ),
                  );
                },
          onLongPress: () {
            final subject = widget.profileUserId ?? me;
            if (_selectedTabIndex != 0 || me == null || subject != me) return;
            if (id == null || id.isEmpty || id == me) return;
            _showRemoveFollowerModal(context, user);
          },
        );
      },
    );
  }
}

class _ConnectionUser {
  const _ConnectionUser({
    this.targetUserId,
    required this.name,
    required this.username,
    required this.avatarUrl,
    this.isVerified = false,
    this.accountType = 'personal',
    this.vipVerified = false,
    this.monetizationEnabled = false,
    this.isFollowing = false,
    this.pendingFollowRequest = false,
  });
  final String? targetUserId;
  final String name;
  final String username;
  final String avatarUrl;
  final bool isVerified;
  final String accountType;
  final bool vipVerified;
  final bool monetizationEnabled;

  /// Whether the signed-in user follows this row (for button state).
  final bool isFollowing;

  /// Pending follow request to a private/personal account.
  final bool pendingFollowRequest;

  _ConnectionUser copyWith({
    bool? isFollowing,
    bool? pendingFollowRequest,
  }) {
    return _ConnectionUser(
      targetUserId: targetUserId,
      name: name,
      username: username,
      avatarUrl: avatarUrl,
      isVerified: isVerified,
      accountType: accountType,
      vipVerified: vipVerified,
      monetizationEnabled: monetizationEnabled,
      isFollowing: isFollowing ?? this.isFollowing,
      pendingFollowRequest: pendingFollowRequest ?? this.pendingFollowRequest,
    );
  }
}

class _ConnectionRow extends StatefulWidget {
  const _ConnectionRow({
    required this.user,
    required this.isFollowing,
    this.pendingFollowRequest = false,
    this.onFollowTap,
    this.onTap,
    this.onLongPress,
  });

  final _ConnectionUser user;
  final bool isFollowing;
  final bool pendingFollowRequest;
  final Future<void> Function()? onFollowTap;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<_ConnectionRow> createState() => _ConnectionRowState();
}

class _ConnectionRowState extends State<_ConnectionRow> {
  late bool _isFollowing;
  late bool _pendingFollowRequest;
  bool _followBusy = false;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.isFollowing;
    _pendingFollowRequest = widget.pendingFollowRequest;
  }

  @override
  void didUpdateWidget(_ConnectionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFollowing != widget.isFollowing) {
      _isFollowing = widget.isFollowing;
    }
    if (oldWidget.pendingFollowRequest != widget.pendingFollowRequest) {
      _pendingFollowRequest = widget.pendingFollowRequest;
    }
  }

  Future<void> _onFollowTap() async {
    if (_followBusy) return;
    final fn = widget.onFollowTap;
    if (fn == null) return;
    setState(() => _followBusy = true);
    try {
      await fn();
      if (mounted) {
        setState(() {
          _isFollowing = widget.isFollowing;
          _pendingFollowRequest = widget.pendingFollowRequest;
        });
      }
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppLightSurface.cardFill,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppLightSurface.background,
                backgroundImage:
                    Uri.tryParse(widget.user.avatarUrl)?.isAbsolute == true
                    ? NetworkImage(widget.user.avatarUrl)
                    : null,
                child: Uri.tryParse(widget.user.avatarUrl)?.isAbsolute != true
                    ? Icon(
                        Icons.person_rounded,
                        color: AppLightSurface.mutedText,
                      )
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
                      style: TextStyle(
                        color: AppLightSurface.primaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '@${widget.user.username}',
                      style: TextStyle(
                        color: AppLightSurface.secondaryText,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _FollowingButton(
                isFollowing: _isFollowing,
                pendingFollowRequest: _pendingFollowRequest,
                accountType: widget.user.accountType,
                busy: _followBusy,
                onTap: _onFollowTap,
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
      color: AppLightSurface.cardFill,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppLightSurface.background,
                backgroundImage:
                    Uri.tryParse(user.avatarUrl)?.isAbsolute == true
                    ? NetworkImage(user.avatarUrl)
                    : null,
                child: Uri.tryParse(user.avatarUrl)?.isAbsolute != true
                    ? Icon(
                        Icons.person_rounded,
                        color: AppLightSurface.mutedText,
                      )
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
                      style: TextStyle(
                        color: AppLightSurface.primaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '@${user.username}',
                      style: TextStyle(
                        color: AppLightSurface.secondaryText,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Material(
                color: AppLightSurface.background,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: InkWell(
                  onTap: onRemove,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppLightSurface.border),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Subscribed',
                          style: TextStyle(
                            color: AppLightSurface.primaryText,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.close,
                          size: 14,
                          color: AppLightSurface.mutedText,
                        ),
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
  const _FollowingButton({
    required this.isFollowing,
    required this.pendingFollowRequest,
    required this.accountType,
    required this.busy,
    required this.onTap,
  });

  final bool isFollowing;
  final bool pendingFollowRequest;
  final String accountType;
  final bool busy;
  final VoidCallback onTap;

  bool get _isRequested =>
      !isFollowing &&
      UserService.accountTypeRequiresFollowApproval(accountType) &&
      pendingFollowRequest;

  String get _label {
    if (isFollowing) return 'Following';
    if (_isRequested) return 'Requested';
    return 'Follow';
  }

  @override
  Widget build(BuildContext context) {
    final background = isFollowing || _isRequested
        ? AppLightSurface.background
        : AppColors.brandPink;
    final foreground = isFollowing || _isRequested
        ? AppLightSurface.primaryText
        : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? () {} : onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: isFollowing ? 12 : 16,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: isFollowing || _isRequested
                ? Border.all(color: AppLightSurface.border)
                : null,
          ),
          child: busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isFollowing || _isRequested
                        ? AppColors.brandPink
                        : Colors.white,
                  ),
                )
              : isFollowing
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _label,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.close,
                      size: 14,
                      color: AppLightSurface.mutedText,
                    ),
                  ],
                )
              : Text(
                  _label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
