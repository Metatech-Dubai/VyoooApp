import 'package:flutter/material.dart';

/// Bottom sheet: brightness slider, then [onApply] with FFmpeg `eq` brightness in \([-1, 1]\).
class ReelBrightnessSheet extends StatefulWidget {
  const ReelBrightnessSheet({
    super.key,
    required this.onApply,
    this.initialEqBrightness = 0,
  });

  /// Called with FFmpeg `eq` brightness; throw on failure so the sheet can show an error.
  final Future<void> Function(double eqBrightness) onApply;

  /// Last applied value in FFmpeg \([-1, 1]\) range (drives initial slider position).
  final double initialEqBrightness;

  @override
  State<ReelBrightnessSheet> createState() => _ReelBrightnessSheetState();
}

class _ReelBrightnessSheetState extends State<ReelBrightnessSheet> {
  static const Color _pink = Color(0xFFDE106B);

  /// UI range; mapped to FFmpeg range in [ReelVideoTone.applyBrightness].
  static const double _sliderMax = 0.45;

  late double _value;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final eq = widget.initialEqBrightness.clamp(-1.0, 1.0);
    _value = (eq * _sliderMax).clamp(-_sliderMax, _sliderMax);
  }

  /// Map slider \([-sliderMax, sliderMax]\) to FFmpeg `eq` \([-1, 1]\).
  double get _ffmpegBrightness => (_value / _sliderMax).clamp(-1.0, 1.0);

  Future<void> _onApply() async {
    setState(() => _busy = true);
    try {
      await widget.onApply(_ffmpegBrightness);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not apply: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    color: _pink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Text(
                'Brightness',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              TextButton(
                onPressed: _busy ? null : _onApply,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _pink,
                        ),
                      )
                    : const Text(
                        'Apply',
                        style: TextStyle(
                          color: _pink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.brightness_low, color: Colors.white.withValues(alpha: 0.7)),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: _pink,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
                    thumbColor: _pink,
                    overlayColor: _pink.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: _value,
                    min: -_sliderMax,
                    max: _sliderMax,
                    onChanged: _busy
                        ? null
                        : (v) {
                            setState(() => _value = v);
                          },
                  ),
                ),
              ),
              Icon(Icons.brightness_high, color: Colors.white.withValues(alpha: 0.7)),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
