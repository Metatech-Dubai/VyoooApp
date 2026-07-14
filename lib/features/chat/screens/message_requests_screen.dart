import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../models/chat_summary_model.dart';
import '../services/chat_service.dart';
import '../utils/chat_helpers.dart';
import 'chat_thread_screen.dart';

class MessageRequestsScreen extends StatefulWidget {
  const MessageRequestsScreen({super.key, required this.requests});

  final List<ChatSummaryModel> requests;

  @override
  State<MessageRequestsScreen> createState() => _MessageRequestsScreenState();
}

class _MessageRequestsScreenState extends State<MessageRequestsScreen> {
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _acceptRequest(ChatSummaryModel summary) async {
    if (_currentUid == null) return;
    await _chatService.acceptMessageRequest(
      uid: _currentUid!,
      chatId: summary.chatId,
    );
    if (!mounted) return;

    final currentUser = await _userService.getUser(_currentUid!);
    if (!mounted || currentUser == null) return;

    final otherUid = summary.participantIds.firstWhere(
      (id) => id != _currentUid,
      orElse: () => '',
    );
    if (otherUid.isEmpty) return;

    final otherUser = await _userService.getUser(otherUid);
    if (!mounted || otherUser == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatThreadScreen(
          chatId: summary.chatId,
          currentUser: currentUser,
          otherUser: otherUser,
        ),
      ),
    );
  }

  // ignore: unused_element
  Future<void> _declineRequest(ChatSummaryModel summary) async {
    if (_currentUid == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.chatBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Decline request',
          style: AppTypography.chatInboxTileName.copyWith(fontSize: 17),
        ),
        content: Text(
          'This conversation will be hidden.',
          style: AppTypography.chatInboxTilePreview.copyWith(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTypography.chatInboxTilePreview.copyWith(
                fontSize: 15,
                color: AppColors.chatTextSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Decline',
              style: TextStyle(color: AppColors.deleteRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _chatService.declineMessageRequest(
      uid: _currentUid!,
      chatId: summary.chatId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.lightEdgeToEdgeOverlay,
        child: Scaffold(
          backgroundColor: AppColors.chatBackground,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.chatTextBlack,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Message requests',
                        style: AppTypography.chatInboxMessagesTitle.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Text(
                    'Open a chat to get more info about who\'s messaging you. They won\'t know that you\'ve seen it until you accept.',
                    style: AppTypography.chatInboxTilePreview.copyWith(
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                Expanded(
                  child: widget.requests.isEmpty
                      ? Center(
                          child: Text(
                            'No message requests',
                            style: AppTypography.chatInboxTilePreview.copyWith(
                              fontSize: 15,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: widget.requests.length,
                          itemBuilder: (context, index) {
                            final summary = widget.requests[index];
                            return _buildRequestRow(summary);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestRow(ChatSummaryModel summary) {
    final hasAvatar = summary.avatarUrl.trim().isNotEmpty;
    final hasUnread = summary.unreadCount > 0;
    return InkWell(
      onTap: () => _acceptRequest(summary),
      splashColor: AppColors.brandDeepMagenta.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.chatSearchFill,
              backgroundImage: hasAvatar
                  ? CachedNetworkImageProvider(summary.avatarUrl)
                  : null,
              child: hasAvatar
                  ? null
                  : const Icon(
                      Icons.person,
                      color: AppColors.chatTextSecondary,
                      size: 24,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          summary.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.chatInboxTileName.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        ChatHelpers.formatInboxTime(summary.lastMessageAt),
                        style: AppTypography.chatInboxTileTime.copyWith(
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (summary.lastMessage.isNotEmpty)
                    Text(
                      summary.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.chatInboxTilePreview.copyWith(
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (hasUnread)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.brandDeepMagenta,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
