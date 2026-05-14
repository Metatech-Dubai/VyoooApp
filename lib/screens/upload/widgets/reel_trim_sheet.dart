import 'package:flutter/material.dart';

/// Bottom sheet: pick start/end of clip on a [RangeSlider], then [onApply].
class ReelTrimSheet extends StatefulWidget {
  const ReelTrimSheet({
    super.key,
    required this.totalDuration,
    required this.initialStart,
    required this.initialEnd,
    required this.onApply,
  });

  final Duration totalDuration;
  final Duration initialStart;
  final Duration initialEnd;

  /// Export trim; throw on failure so the sheet can stay open and clear loading.
  final Future<void> Function(Duration start, Duration end) onApply;

  static String formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  State<ReelTrimSheet> createState() => _ReelTrimSheetState();
}

class _ReelTrimSheetState extends State<ReelTrimSheet> {
  static const double _minGapMs = 500;

  late double _startMs;
  late double _endMs;
  bool _busy = false;

  double get _totalMs =>
      widget.totalDuration.inMilliseconds.clamp(1, 1 << 30).toDouble();

  @override
  void initState() {
    super.initState();
    _startMs = widget.initialStart.inMilliseconds
        .clamp(0, widget.totalDuration.inMilliseconds)
        .toDouble();
    _endMs = widget.initialEnd.inMilliseconds
        .clamp(0, widget.totalDuration.inMilliseconds)
        .toDouble();
    if (_endMs - _startMs < _minGapMs) {
      _endMs = (_startMs + _minGapMs).clamp(_minGapMs, _totalMs);
    }
    if (_endMs <= _startMs) {
      _startMs = 0;
      _endMs = _totalMs;
    }
  }

  void _onRangeChanged(RangeValues v) {
    final t = _totalMs;
    var s = v.start * t;
    var e = v.end * t;
    if (e - s < _minGapMs) {
      if (e >= t - 1) {
        s = (e - _minGapMs).clamp(0, t);
      } else {
        e = (s + _minGapMs).clamp(0, t);
      }
    }
    setState(() {
      _startMs = s;
      _endMs = e;
    });
  }

  Duration get _startD => Duration(milliseconds: _startMs.round());
  Duration get _endD => Duration(milliseconds: _endMs.round());
  Duration get _spanD => Duration(milliseconds: (_endMs - _startMs).round());

  Future<void> _onApplyPressed() async {
    setState(() => _busy = true);
    try {
      await widget.onApply(_startD, _endD);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trim failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const pink = Color(0xFFDE106B);
    final startFrac = (_startMs / _totalMs).clamp(0.0, 1.0);
    final endFrac = (_endMs / _totalMs).clamp(0.0, 1.0);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E0A1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.paddingOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: pink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Text(
                'Trim',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              TextButton(
                onPressed: _busy ? null : _onApplyPressed,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: pink,
                        ),
                      )
                    : const Text(
                        'Apply',
                        style: TextStyle(
                          color: pink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),
          Text(
            'Start ${ReelTrimSheet.formatDuration(_startD)}  ·  End ${ReelTrimSheet.formatDuration(_endD)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Length ${ReelTrimSheet.formatDuration(_spanD)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          SliderTheme(
            data: SliderThemeData(
              rangeThumbShape: const RoundRangeSliderThumbShape(
                enabledThumbRadius: 8,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: pink,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
              thumbColor: pink,
              overlayColor: pink.withValues(alpha: 0.2),
            ),
            child: RangeSlider(
              values: RangeValues(startFrac, endFrac),
              max: 1,
              onChanged: _busy ? null : _onRangeChanged,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
