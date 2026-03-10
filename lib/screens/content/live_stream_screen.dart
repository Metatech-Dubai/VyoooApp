import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_bottom_navigation.dart';

/// Payload for opening live stream full-screen (from profile streams or search).
class LiveStreamPayload {
  const LiveStreamPayload({
    this.title = 'Live',
    this.streamTitle = 'Greenery',
    this.streamDescription = 'Watch live as the balloon soars in the sky at 6:30 am ist',
    this.thumbnailUrl = 'https://picsum.photos/800/1600?random=livefull',
    this.likeCount = 223,
    this.avatarUrl = 'https://i.pravatar.cc/80?img=33',
  });

  final String title;
  final String streamTitle;
  final String streamDescription;
  final String thumbnailUrl;
  final int likeCount;
  final String avatarUrl;
}

/// Mock chat message for live stream.
class _ChatMessage {
  const _ChatMessage({required this.handle, required this.message, required this.avatarUrl});
  final String handle;
  final String message;
  final String avatarUrl;
}

const List<_ChatMessage> _liveStreamMockChatMessages = [
  _ChatMessage(handle: 'Adam123.33', message: 'Look how beautiful it looks 😍', avatarUrl: 'https://i.pravatar.cc/80?img=1'),
  _ChatMessage(handle: 'Srishtichauhan', message: 'So peaceful!', avatarUrl: 'https://i.pravatar.cc/80?img=2'),
  _ChatMessage(handle: 'Louisa Mole', message: 'Amazing view', avatarUrl: 'https://i.pravatar.cc/80?img=3'),
  _ChatMessage(handle: 'John Mark', message: 'Wish I was there', avatarUrl: 'https://i.pravatar.cc/80?img=4'),
  _ChatMessage(handle: 'Emma_J', message: '🔥🔥', avatarUrl: 'https://i.pravatar.cc/80?img=5'),
];

/// Full-screen live stream: back + "Live", video with LIVE+VR badges, chat overlay, comment input, heart/share, stream title.
class LiveStreamScreen extends StatefulWidget {
  const LiveStreamScreen({super.key, this.payload});

  final LiveStreamPayload? payload;

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  int _currentBottomNavIndex = 4;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payload ?? const LiveStreamPayload();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(p.thumbnailUrl, fit: BoxFit.cover),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.5),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.9),
                ],
                stops: const [0.0, 0.12, 0.5, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                const Spacer(),
                _buildChatAndInput(p),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            right: AppSpacing.md,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.deleteRed,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'VR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: _currentBottomNavIndex,
        onTap: (index) {
          if (index == 4) return;
          setState(() => _currentBottomNavIndex = index);
        },
        profileImageUrl: widget.payload?.avatarUrl,
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Text(
            'Live',
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

  Widget _buildChatAndInput(LiveStreamPayload p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    p.streamTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      itemCount: _liveStreamMockChatMessages.length,
                      itemBuilder: (context, index) {
                        final m = _liveStreamMockChatMessages[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.white.withValues(alpha: 0.2),
                                backgroundImage: NetworkImage(m.avatarUrl),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: RichText(
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  text: TextSpan(
                                    style: const TextStyle(fontSize: 13, height: 1.3),
                                    children: [
                                      TextSpan(
                                        text: '${m.handle} ',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      TextSpan(
                                        text: m.message,
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Comment...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withValues(alpha: 0.7), size: 24),
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.favorite_rounded, color: Colors.white.withValues(alpha: 0.9), size: 24),
                const SizedBox(width: 4),
                Text(
                  '${p.likeCount}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.share_rounded, color: Colors.white.withValues(alpha: 0.9), size: 24),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            p.streamDescription,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
