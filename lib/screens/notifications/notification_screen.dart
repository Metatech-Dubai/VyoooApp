import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_gradient_background.dart';

/// Notifications tab: list with "Today" section or empty state.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  /// Toggle to test empty state. Set to true to show empty, false to show mock list.
  static const bool _useEmptyState = false;

  static final List<_NotificationItem> _mockNotifications = [
    _NotificationItem(
      avatarUrl: 'https://i.pravatar.cc/80?img=33',
      message: 'You started following Dennis_Nedry',
      timeAgo: '2h',
    ),
    _NotificationItem(
      avatarUrl: 'https://i.pravatar.cc/80?img=24',
      message: 'Lesilelongbottom added a new post',
      timeAgo: '2h',
    ),
    _NotificationItem(
      avatarUrl: 'https://i.pravatar.cc/80?img=12',
      message: "Haridesigne commented: Nicce 🔥 on lesilelongbottom's post.",
      timeAgo: '2h',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final items = _useEmptyState ? <_NotificationItem>[] : _mockNotifications;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType.feed,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAppBar(context),
            Expanded(
              child: items.isEmpty ? _buildEmptyState() : _buildNotificationList(items),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 32),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          const Text(
            'Notifications',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 80,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No new notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.95),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              "You're all caught up!",
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationList(List<_NotificationItem> items) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      children: [
        Text(
          'Today',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ...items.map((item) => _NotificationTile(item: item)),
      ],
    );
  }
}

class _NotificationItem {
  const _NotificationItem({
    required this.avatarUrl,
    required this.message,
    required this.timeAgo,
  });

  final String avatarUrl;
  final String message;
  final String timeAgo;
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});

  final _NotificationItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            backgroundImage: Uri.tryParse(item.avatarUrl)?.isAbsolute == true
                ? NetworkImage(item.avatarUrl)
                : null,
            child: Uri.tryParse(item.avatarUrl)?.isAbsolute != true
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
                  item.message,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.95),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.timeAgo,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
