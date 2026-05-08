import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/user_service.dart';
import '../controllers/chat_controller.dart';
import '../models/chat_summary_model.dart';
import '../utils/chat_constants.dart';
import '../widgets/chat_tile.dart';
import 'chat_thread_screen.dart';
import 'message_requests_screen.dart';
import 'new_message_screen.dart';

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final ChatController _controller;
  final UserService _userService = UserService();
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid;
    _controller = ChatController(uid: _currentUid ?? '');
    _controller.addListener(_onControllerChange);
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    _controller.dispose();
    super.dispose();
  }

  List<ChatSummaryModel> get _primarySummaries {
    return _controller.summaries.where((s) {
      final rs = s.requestStatus;
      return rs == null ||
          rs == RequestStatus.none ||
          rs == RequestStatus.accepted;
    }).toList();
  }

  List<ChatSummaryModel> get _requestSummaries {
    return _controller.summaries.where((s) {
      return s.requestStatus == RequestStatus.pending;
    }).toList();
  }

  Future<void> _openThread(ChatSummaryModel summary) async {
    if (_currentUid == null) return;

    final currentUser = await _userService.getUser(_currentUid!);
    if (!mounted || currentUser == null) return;

    if (summary.type == ChatTypes.group) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatThreadScreen(
            chatId: summary.chatId,
            currentUser: currentUser,
            chatType: ChatTypes.group,
            groupName: summary.title,
            groupImageUrl: summary.avatarUrl,
            participantIds: summary.participantIds,
          ),
        ),
      );
      return;
    }

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

  void _openNewMessage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const NewMessageScreen()));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFF07010F),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.45, 1.0],
                  colors: [
                    Color(0xFF1A0826),
                    Color(0xFF10041A),
                    Color(0xFF07010F),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -100,
            left: -100,
            right: -100,
            child: Container(
              height: 420,
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0x88DE106B), Color(0x00000000)],
                  radius: 0.75,
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                _ChatNotesRow(
                  summaries: _primarySummaries,
                  currentUid: _currentUid,
                  onTapNote: (summary) {
                    if (summary != null) {
                      _openThread(summary);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notes coming soon'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                ),
                _buildMessagesSectionHeader(),
                Expanded(child: _buildInboxList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Row(
        children: [
          const Icon(Icons.menu, color: Colors.white70, size: 22),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                FirebaseAuth.instance.currentUser?.displayName ?? 'Messages',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white54,
                size: 18,
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _openNewMessage,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF1E0D33),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.edit_square,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF1C0B2E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x22FFFFFF), width: 0.5),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(
              Icons.search,
              color: Colors.white.withValues(alpha: 0.35),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Search',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesSectionHeader() {
    final requestCount = _requestSummaries.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
      child: Row(
        children: [
          const Text(
            'Messages',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (requestCount > 0)
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        MessageRequestsScreen(requests: _requestSummaries),
                  ),
                );
              },
              child: Text(
                'Requests ($requestCount)',
                style: const TextStyle(
                  color: AppColors.brandDeepMagenta,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInboxList() {
    if (_controller.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandMagenta),
      );
    }

    if (_controller.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.white.withValues(alpha: 0.3),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              _controller.error!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final summaries = _primarySummaries;
    if (summaries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              color: Colors.white.withValues(alpha: 0.2),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'No conversations yet',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _openNewMessage,
              child: const Text(
                'Start a conversation',
                style: TextStyle(
                  color: AppColors.brandMagenta,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 80),
      itemCount: summaries.length,
      itemBuilder: (context, index) {
        final summary = summaries[index];
        return ChatTile(summary: summary, onTap: () => _openThread(summary));
      },
    );
  }
}

class _ChatNotesRow extends StatelessWidget {
  const _ChatNotesRow({
    required this.summaries,
    required this.currentUid,
    required this.onTapNote,
  });

  final List<ChatSummaryModel> summaries;
  final String? currentUid;
  final void Function(ChatSummaryModel?) onTapNote;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final seen = <String>{};
    final noteUsers = <_NoteUser>[];

    for (final s in summaries) {
      if (s.type == ChatTypes.group) continue;
      final otherUid = s.participantIds.firstWhere(
        (id) => id != currentUid,
        orElse: () => '',
      );
      if (otherUid.isEmpty || seen.contains(otherUid)) continue;
      seen.add(otherUid);
      noteUsers.add(
        _NoteUser(name: s.title, avatarUrl: s.avatarUrl, summary: s),
      );
    }

    return SizedBox(
      height: 94,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
        itemCount: noteUsers.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _ChatNoteItem(
              name: currentUser?.displayName ?? 'Your note',
              avatarUrl: currentUser?.photoURL,
              noteText: 'Note...',
              isCurrentUser: true,
              onTap: () => onTapNote(null),
            );
          }
          final user = noteUsers[index - 1];
          return _ChatNoteItem(
            name: user.name,
            avatarUrl: user.avatarUrl.isNotEmpty ? user.avatarUrl : null,
            noteText: null,
            isCurrentUser: false,
            onTap: () => onTapNote(user.summary),
          );
        },
      ),
    );
  }
}

class _NoteUser {
  const _NoteUser({
    required this.name,
    required this.avatarUrl,
    required this.summary,
  });
  final String name;
  final String avatarUrl;
  final ChatSummaryModel summary;
}

class _ChatNoteItem extends StatelessWidget {
  const _ChatNoteItem({
    required this.name,
    required this.avatarUrl,
    required this.noteText,
    required this.isCurrentUser,
    required this.onTap,
  });

  final String name;
  final String? avatarUrl;
  final String? noteText;
  final bool isCurrentUser;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 64,
              width: 68,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    bottom: 0,
                    left: 6,
                    right: 6,
                    child: _buildAvatar(),
                  ),
                  if (noteText != null)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _NoteBubble(text: noteText!),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _displayName {
    if (isCurrentUser) return 'Your note';
    if (name.length > 9) return '${name.substring(0, 8)}…';
    return name;
  }

  Widget _buildAvatar() {
    final hasImage = avatarUrl != null && avatarUrl!.trim().isNotEmpty;
    return Container(
      width: 50,
      height: 50,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF2A1B2E),
      ),
      child: CircleAvatar(
        radius: 25,
        backgroundColor: const Color(0xFF2A1B2E),
        backgroundImage: hasImage
            ? CachedNetworkImageProvider(avatarUrl!)
            : null,
        child: hasImage
            ? null
            : const Icon(Icons.person, color: Colors.white38, size: 22),
      ),
    );
  }
}

class _NoteBubble extends StatelessWidget {
  const _NoteBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xDD2A1B2E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 0.5,
          ),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
