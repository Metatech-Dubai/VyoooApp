import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.text,
    required this.isSent,
    required this.time,
    this.isDeleted = false,
    this.senderName,
    this.seenText,
  });

  final String text;
  final bool isSent;
  final String time;
  final bool isDeleted;
  final String? senderName;
  final String? seenText;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        margin: EdgeInsets.only(
          left: isSent ? 60 : 10,
          right: isSent ? 10 : 60,
          top: 2,
          bottom: 2,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSent
              ? const LinearGradient(
                  colors: [Color(0xFFDE106B), Color(0xFF6B21A8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSent ? null : const Color(0xFF1E0E2E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isSent ? 18 : 4),
            bottomRight: Radius.circular(isSent ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (senderName != null && !isSent)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  senderName!,
                  style: const TextStyle(
                    color: AppColors.brandMagenta,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Text(
              isDeleted ? 'This message was deleted' : text,
              style: TextStyle(
                color: isDeleted
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.white,
                fontSize: 14,
                fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
              ),
            ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (seenText != null) ...[
                    Text(
                      seenText!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    time,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
