import 'package:flutter/material.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/user_service.dart';
import '../../../core/utils/user_facing_errors.dart';
import 'block_user_sheet.dart';

/// Instagram-style profile report: pick a reason, then thank-you with block/unfollow.
void showReportUserSheet(
  BuildContext context, {
  required String username,
  required String avatarUrl,
  required String targetUserId,
  bool isFollowing = false,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ReportUserSheetFlow(
      username: username,
      avatarUrl: avatarUrl,
      targetUserId: targetUserId,
      isFollowing: isFollowing,
    ),
  );
}

class _ReportUserSheetFlow extends StatefulWidget {
  const _ReportUserSheetFlow({
    required this.username,
    required this.avatarUrl,
    required this.targetUserId,
    this.isFollowing = false,
  });

  final String username;
  final String avatarUrl;
  final String targetUserId;
  final bool isFollowing;

  @override
  State<_ReportUserSheetFlow> createState() => _ReportUserSheetFlowState();
}

class _ReportUserSheetFlowState extends State<_ReportUserSheetFlow> {
  bool _showThanks = false;
  bool _isOtherActionsExpanded = false;
  bool _isSubmitting = false;
  late bool _isFollowing;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.isFollowing;
  }

  static const List<String> _reasons = [
    'Posting inappropriate content',
    'Harassment or bullying',
    'Pretending to be someone else',
    'Spam or scam',
    'Hate speech or discrimination',
    'I just don\'t like it',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF49113B),
            Color(0xFF210D1D),
            Color(0xFF0F040C),
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    _showThanks ? 'Report' : 'Report @${widget.username}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!_showThanks) _buildReasonsList() else _buildThanksView(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonsList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Text(
            'Why are you reporting this account?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
        ..._reasons.map(
          (reason) => _ReasonTile(
            label: reason,
            onTap: () => _onReasonSelected(reason),
          ),
        ),
      ],
    );
  }

  Future<void> _onReasonSelected(String reason) async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _showThanks = true;
    });
    try {
      await UserService().reportUser(
        reportedUserId: widget.targetUserId,
        reason: reason,
      );
    } catch (_) {
      // Reporting is best-effort; failures must not block the UX.
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildThanksView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 32),
        const Text(
          'Thanks for your feedback',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'We use these reports to help keep VyooO safe. Your report is anonymous.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              InkWell(
                onTap: () =>
                    setState(() => _isOtherActionsExpanded = !_isOtherActionsExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      const Text(
                        'Other Actions',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        _isOtherActionsExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isOtherActionsExpanded) ...[
                _ActionItem(
                  icon: Icons.block_flipped,
                  label: 'Block User',
                  labelColor: const Color(0xFFEF4444),
                  onTap: () {
                    Navigator.of(context).pop();
                    showBlockUserSheet(
                      context,
                      username: widget.username,
                      avatarUrl: widget.avatarUrl,
                      targetUserId: widget.targetUserId,
                    );
                  },
                ),
                if (_isFollowing)
                  _ActionItem(
                    icon: Icons.person_remove_outlined,
                    label: 'Unfollow User',
                    onTap: _onUnfollowFromReport,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _onUnfollowFromReport() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final target = widget.targetUserId;
    final me = AuthService().currentUser?.uid;
    if (me == null || me.isEmpty) {
      Navigator.of(context).pop();
      messenger?.showSnackBar(
        const SnackBar(content: Text('Sign in to manage who you follow.')),
      );
      return;
    }
    if (!_isFollowing) {
      Navigator.of(context).pop();
      return;
    }
    try {
      await UserService().unfollowUser(currentUid: me, targetUid: target);
      if (!mounted) return;
      setState(() => _isFollowing = false);
      messenger?.showSnackBar(
        const SnackBar(content: Text('You unfollowed this account.')),
      );
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(messageForFirestore(e))));
    }
    if (mounted) Navigator.of(context).pop();
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.icon,
    required this.label,
    this.labelColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(
              icon,
              color: labelColor ?? Colors.white.withValues(alpha: 0.7),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: labelColor ?? Colors.white.withValues(alpha: 0.7),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
