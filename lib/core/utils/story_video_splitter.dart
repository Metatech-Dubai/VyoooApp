import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Splits a long video into ≤60s MP4 segments (H.264 + AAC) for sequential stories.
class StoryVideoSplitter {
  StoryVideoSplitter._();
  static const int maxSegmentSeconds = 60;

  /// Returns one file per segment (each at most [maxSegmentSeconds] long).
  static Future<List<File>> splitToSegments(
    File input,
    Duration totalDuration,
  ) async {
    final totalSec = totalDuration.inMilliseconds / 1000.0;
    if (totalSec <= 0) {
      return [input];
    }
    if (totalSec <= maxSegmentSeconds + 0.01) {
      return [input];
    }

    final dir = await getTemporaryDirectory();
    final out = <File>[];
    final n = (totalSec / maxSegmentSeconds).ceil();
    final base =
        'vy_story_${DateTime.now().millisecondsSinceEpoch}_${input.hashCode}';

    for (var i = 0; i < n; i++) {
      final start = i * maxSegmentSeconds;
      final remaining = totalSec - start;
      final len = remaining > maxSegmentSeconds
          ? maxSegmentSeconds.toDouble()
          : remaining;
      final outPath = '${dir.path}/${base}_$i.mp4';

      final args = <String>[
        '-y',
        '-i',
        input.path,
        '-ss',
        start.toStringAsFixed(3),
        '-t',
        len.toStringAsFixed(3),
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
        debugPrint('StoryVideoSplitter FFmpeg failed: $logs');
        for (final f in out) {
          try {
            if (f.existsSync()) f.deleteSync();
          } catch (_) {}
        }
        throw Exception('Could not split video for stories.');
      }
      out.add(File(outPath));
    }

    return out;
  }
}
