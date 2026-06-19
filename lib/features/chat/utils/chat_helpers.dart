import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/message_model.dart';
import 'chat_constants.dart';

abstract final class ChatHelpers {
  static String directChatId(String uidA, String uidB) {
    if (uidA.trim().isEmpty || uidB.trim().isEmpty) {
      throw ArgumentError('UIDs must not be empty');
    }
    if (uidA == uidB) {
      throw ArgumentError('UIDs must be different');
    }
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  static String buildTextPreview(String text, {int maxLength = 100}) {
    final trimmed = text.trim();
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength)}…';
  }

  static String messageBodyPreview(MessageModel message, {int maxLength = 80}) {
    if (message.deletedForEveryone) return 'Message deleted';
    switch (message.type) {
      case ChatMessageTypes.text:
        final trimmed = message.text.trim();
        if (trimmed.isEmpty) return 'Message';
        return buildTextPreview(trimmed, maxLength: maxLength);
      case ChatMessageTypes.image:
        return message.isViewOnce ? 'View-once photo' : 'Photo';
      case ChatMessageTypes.video:
        return message.isViewOnce ? 'View-once video' : 'Video';
      case ChatMessageTypes.audio:
        return 'Voice message';
      case ChatMessageTypes.gif:
        return 'GIF';
      case ChatMessageTypes.call:
        return message.text.trim().isNotEmpty ? message.text.trim() : 'Call';
      default:
        return 'Message';
    }
  }

  static String formatInboxTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Reads avatar from a chat [participantMap] entry (`avatarUrl` is canonical).
  static String? participantAvatarFromMap(Map<String, dynamic>? participant) {
    if (participant == null) return null;
    for (final key in ['avatarUrl', 'profileImage', 'photoURL']) {
      final value = (participant[key] as String?)?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static String? participantDisplayNameFromMap(
    Map<String, dynamic>? participant,
  ) {
    if (participant == null) return null;
    final displayName = (participant['displayName'] as String?)?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final username = (participant['username'] as String?)?.trim();
    if (username != null && username.isNotEmpty) return username;
    return null;
  }
}