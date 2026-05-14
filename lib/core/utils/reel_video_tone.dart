import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Single-pass video tone adjustments for reel export (FFmpeg).
class ReelVideoTone {
  ReelVideoTone._();

  /// Applies FFmpeg `eq` brightness only. [brightness] uses FFmpeg range \([-1, 1]\);
  /// values with magnitude below 0.02 return [input] without re-encoding.
  static Future<File> applyBrightness({
    required File input,
    required double brightness,
  }) async {
    if (!await input.exists()) {
      throw StateError('Input video does not exist');
    }
    final b = brightness.clamp(-1.0, 1.0);
    if (b.abs() < 0.02) {
      return input;
    }

    final dir = await getTemporaryDirectory();
    final outPath =
        '${dir.path}/vy_reel_adj_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final vf =
        'eq=brightness=${b.toStringAsFixed(4)}:contrast=1.0:saturation=1.0';

    final args = <String>[
      '-y',
      '-i',
      input.path,
      '-vf',
      vf,
      '-c:v',
      'libx264',
      '-pix_fmt',
      'yuv420p',
      '-preset',
      'veryfast',
      '-crf',
      '23',
      '-c:a',
      'aac',
      '-b:a',
      '128k',
      '-movflags',
      '+faststart',
      outPath,
    ];

    final session = await FFmpegKit.executeWithArguments(args);
    final code = await session.getReturnCode();
    if (!ReturnCode.isSuccess(code)) {
      final logs = await session.getLogsAsString();
      debugPrint('ReelVideoTone FFmpeg failed: $logs');
      try {
        final f = File(outPath);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
      throw Exception('Could not apply brightness');
    }

    return File(outPath);
  }
}
