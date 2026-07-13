import 'package:flutter/material.dart';

import '../utils/reaction_helpers.dart';

class MessageReactionsBar extends StatelessWidget {
  const MessageReactionsBar({
    super.key,
    required this.reactions,
    required this.isSent,
    this.currentUid,
    this.onReactionTap,
  });

  final Map<String, dynamic> reactions;
  final bool isSent;
  final String? currentUid;
  final void Function(String emoji)? onReactionTap;

  @override
  Widget build(BuildContext context) {
    final grouped = nonHeartReactions(reactions);
    if (grouped.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(
        left: isSent ? 60 : 10,
        right: isSent ? 10 : 60,
        top: 0,
        bottom: 4,
      ),
      child: Align(
        alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: grouped.entries.map((entry) {
            final emoji = entry.key;
            final uids = entry.value;
            final isMine =
                currentUid != null && uids.contains(currentUid);
            return GestureDetector(
              onTap: onReactionTap == null
                  ? null
                  : () => onReactionTap!(emoji),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isMine
                      ? const Color(0xFFDE106B).withValues(alpha: 0.25)
                      : const Color(0xFF1E0E2E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isMine
                        ? const Color(0xFFDE106B).withValues(alpha: 0.5)
                        : Colors.white12,
                  ),
                ),
                child: Text(
                  uids.length > 1 ? '$emoji ${uids.length}' : emoji,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
