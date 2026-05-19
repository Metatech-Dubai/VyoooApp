import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../interest_chip.dart';

/// Horizontally auto-scrolling chip row (Instagram-style marquee).
///
/// [slideLeft] true: content drifts left. false: drifts right.
class AutoSlidingChipRow extends StatefulWidget {
  const AutoSlidingChipRow({
    super.key,
    required this.labels,
    required this.slideLeft,
    required this.isSelected,
    required this.onToggle,
    this.height = 48,
    this.chipGap = 10,
    this.pixelsPerSecond = 30,
  });

  final List<String> labels;
  final bool slideLeft;
  final bool Function(String label) isSelected;
  final ValueChanged<String> onToggle;
  final double height;
  final double chipGap;
  final double pixelsPerSecond;

  @override
  State<AutoSlidingChipRow> createState() => _AutoSlidingChipRowState();
}

class _AutoSlidingChipRowState extends State<AutoSlidingChipRow>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  Ticker? _ticker;
  double _lastElapsedSeconds = 0;
  double _loopExtent = 0;
  bool _userDragging = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_measureLoopExtent);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleStart());
  }

  @override
  void didUpdateWidget(AutoSlidingChipRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.labels != widget.labels ||
        oldWidget.slideLeft != widget.slideLeft) {
      _loopExtent = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _measureLoopExtent();
      });
    }
  }

  void _scheduleStart() {
    if (!mounted) return;
    _measureLoopExtent();
    _ticker ??= createTicker(_onTick)..start();
  }

  void _measureLoopExtent() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) {
      _loopExtent = 0;
      return;
    }
    // List is duplicated once; one copy width = half of scrollable range.
    _loopExtent = max / 2;
  }

  void _onTick(Duration elapsed) {
    if (!mounted || _userDragging || _loopExtent <= 0) {
      _lastElapsedSeconds = elapsed.inMicroseconds / 1e6;
      return;
    }
    if (!_scrollController.hasClients) return;

    final now = elapsed.inMicroseconds / 1e6;
    final dt = (now - _lastElapsedSeconds).clamp(0.0, 0.05);
    _lastElapsedSeconds = now;

    if (_loopExtent <= 0) _measureLoopExtent();
    if (_loopExtent <= 0) return;

    final delta = widget.pixelsPerSecond * dt * (widget.slideLeft ? 1 : -1);
    var next = _scrollController.offset + delta;

    while (next >= _loopExtent) {
      next -= _loopExtent;
    }
    while (next < 0) {
      next += _loopExtent;
    }

    _scrollController.jumpTo(next);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.labels.isEmpty) {
      return SizedBox(height: widget.height);
    }

    final loopLabels = [...widget.labels, ...widget.labels];

    return SizedBox(
      height: widget.height,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification &&
              notification.dragDetails != null) {
            setState(() => _userDragging = true);
          } else if (notification is ScrollEndNotification) {
            setState(() => _userDragging = false);
          }
          return false;
        },
        child: ListView.separated(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          itemCount: loopLabels.length,
          separatorBuilder: (_, _) => SizedBox(width: widget.chipGap),
          itemBuilder: (context, index) {
            final label = loopLabels[index];
            return InterestChip(
              label: label,
              isSelected: widget.isSelected(label),
              onTap: () => widget.onToggle(label),
            );
          },
        ),
      ),
    );
  }
}

/// Vertical stack of alternating auto-slide rows.
class AutoSlidingChipRows extends StatelessWidget {
  const AutoSlidingChipRows({
    super.key,
    required this.rows,
    required this.isSelected,
    required this.onToggle,
    this.rowHeight = 48,
    this.rowGap = 12,
    this.chipGap = 10,
    this.basePixelsPerSecond = 28,
  });

  final List<List<String>> rows;
  final bool Function(String label) isSelected;
  final ValueChanged<String> onToggle;
  final double rowHeight;
  final double rowGap;
  final double chipGap;
  final double basePixelsPerSecond;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) SizedBox(height: rowGap),
          AutoSlidingChipRow(
            labels: rows[r],
            slideLeft: r.isEven,
            isSelected: isSelected,
            onToggle: onToggle,
            height: rowHeight,
            chipGap: chipGap,
            pixelsPerSecond: basePixelsPerSecond + (r % 3) * 4,
          ),
        ],
      ],
    );
  }
}
