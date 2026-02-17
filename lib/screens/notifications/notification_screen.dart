import 'package:flutter/material.dart';

import '../../core/theme/app_padding.dart';
import '../../core/theme/app_spacing.dart';

/// Notifications tab. Handle permissions correctly (request when user opts in).
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0D0015),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_none_rounded,
                size: 64,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              AppPadding.itemGap,
              Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                'No new notifications',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
