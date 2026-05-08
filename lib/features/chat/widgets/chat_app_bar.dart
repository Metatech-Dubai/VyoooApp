import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/models/app_user_model.dart';
import '../utils/chat_constants.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({
    super.key,
    this.otherUser,
    this.chatType = ChatTypes.direct,
    this.groupName,
    this.groupImageUrl,
    this.memberCount,
    this.isMuted = false,
    this.onMenuMute,
    this.onMenuClear,
    this.onMenuGroupInfo,
    this.presenceText,
    this.onAudioCall,
    this.onVideoCall,
    this.onHeaderTap,
  });

  final AppUserModel? otherUser;
  final String chatType;
  final String? groupName;
  final String? groupImageUrl;
  final int? memberCount;
  final bool isMuted;
  final VoidCallback? onMenuMute;
  final VoidCallback? onMenuClear;
  final VoidCallback? onMenuGroupInfo;
  final String? presenceText;
  final VoidCallback? onAudioCall;
  final VoidCallback? onVideoCall;
  final VoidCallback? onHeaderTap;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  bool get _isGroup => chatType == ChatTypes.group;

  String get _displayName {
    if (_isGroup) return groupName ?? 'Group';
    final u = otherUser;
    if (u == null) return '';
    final dn = (u.displayName ?? '').trim();
    return dn.isNotEmpty ? dn : u.username ?? '';
  }

  String? get _subtitle {
    if (presenceText != null && presenceText!.isNotEmpty) return presenceText;
    if (_isGroup && memberCount != null) return '$memberCount members';
    if (!_isGroup) {
      final u = otherUser;
      if (u != null && (u.username ?? '').trim().isNotEmpty) {
        return '@${u.username}';
      }
    }
    return null;
  }

  String? get _avatarUrl {
    if (_isGroup) return groupImageUrl;
    return otherUser?.profileImage;
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _avatarUrl;
    final hasAvatar = avatar != null && avatar.trim().isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E0A30), Color(0xFF150820)],
        ),
        border: Border(
          bottom: BorderSide(color: Color(0x33DE106B), width: 0.5),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: () => Navigator.of(context).pop(),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: GestureDetector(
                  onTap: onHeaderTap,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFDE106B), Color(0xFF6B21A8)],
                          ),
                        ),
                        padding: const EdgeInsets.all(1.5),
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: const Color(0xFF1A0A2E),
                          backgroundImage: hasAvatar
                              ? CachedNetworkImageProvider(avatar)
                              : null,
                          child: hasAvatar
                              ? null
                              : Icon(
                                  _isGroup ? Icons.group : Icons.person,
                                  color: Colors.white54,
                                  size: 15,
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_subtitle != null)
                              Text(
                                _subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: presenceText == 'Active now'
                                      ? const Color(0xFF4CAF50)
                                      : Colors.white.withValues(alpha: 0.4),
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (onAudioCall != null)
                IconButton(
                  icon: const Icon(
                    Icons.call_outlined,
                    color: Colors.white70,
                    size: 21,
                  ),
                  onPressed: onAudioCall,
                  tooltip: 'Audio call',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              if (onVideoCall != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: IconButton(
                    icon: const Icon(
                      Icons.videocam_outlined,
                      color: Colors.white70,
                      size: 21,
                    ),
                    onPressed: onVideoCall,
                    tooltip: 'Video call',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: Colors.white70,
                  size: 21,
                ),
                padding: EdgeInsets.zero,
                color: const Color(0xFF1A0A2E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'mute':
                      onMenuMute?.call();
                    case 'clear':
                      onMenuClear?.call();
                    case 'group_info':
                      onMenuGroupInfo?.call();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'mute',
                    child: Text(
                      isMuted ? 'Unmute' : 'Mute',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clear',
                    child: Text(
                      'Clear chat',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  if (_isGroup)
                    const PopupMenuItem(
                      value: 'group_info',
                      child: Text(
                        'Group info',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
