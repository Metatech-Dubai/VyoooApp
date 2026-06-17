import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';

/// Swipe a message to the right to trigger [onReply] (iMessage / WhatsApp style).
class SwipeToReplyMessage extends StatefulWidget {
  const SwipeToReplyMessage({
    super.key,
    required this.child,
    required this.onReply,
    this.enabled = true,
    this.onLongPress,
    this.onDoubleTap,
  });

  final Widget child;
  final VoidCallback onReply;
  final bool enabled;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;

  @override
  State<SwipeToReplyMessage> createState() => _SwipeToReplyMessageState();
}

class _SwipeToReplyMessageState extends State<SwipeToReplyMessage> {
  static const double _triggerThreshold = 56;
  static const double _maxDrag = 72;

  double _dragExtent = 0;

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;
    setState(() {
      _dragExtent = (_dragExtent + details.delta.dx).clamp(0.0, _maxDrag);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!widget.enabled) return;
    if (_dragExtent >= _triggerThreshold) {
      HapticFeedback.mediumImpact();
      widget.onReply();
    }
    setState(() => _dragExtent = 0);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return GestureDetector(
        onLongPress: widget.onLongPress,
        onDoubleTap: widget.onDoubleTap,
        behavior: HitTestBehavior.opaque,
        child: widget.child,
      );
    }

    final progress = (_dragExtent / _triggerThreshold).clamp(0.0, 1.0);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.centerLeft,
      children: [
        Positioned(
          left: 4,
          child: Opacity(
            opacity: progress,
            child: Icon(
              Icons.reply_rounded,
              color: AppColors.brandMagenta.withValues(alpha: 0.85),
              size: 22,
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(_dragExtent, 0),
          child: GestureDetector(
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            onLongPress: widget.onLongPress,
            onDoubleTap: widget.onDoubleTap,
            behavior: HitTestBehavior.opaque,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
