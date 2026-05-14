import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Exports a time range of a video to MP4 (H.264 + AAC) for reel upload.
class ReelVideoTrimmer {
  ReelVideoTrimmer._();

  /// [end] is the exclusive end time in the same sense as FFmpeg `-t` duration
  /// (we pass `-ss` [start] and `-t` as [end] - [start]).
  static Future<File> trimToMp4({
    required File input,
    required Duration start,
    required Duration end,
  }) async {
    if (!await input.exists()) {
      throw StateError('Input video does not exist');
    }
    if (end.compareTo(start) <= 0) {
      throw ArgumentError.value(end, 'end', 'must be after start');
    }
    final span = end - start;
    if (span.inMilliseconds < 400) {
      throw ArgumentError('Selected clip is too short');
    }

    final dir = await getTemporaryDirectory();
    final outPath =
        '${dir.path}/vy_reel_trim_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final startSec = (start.inMicroseconds / 1e6).toStringAsFixed(3);
    final durationSec = (span.inMicroseconds / 1e6).toStringAsFixed(3);

    final args = <String>[
      '-y',
      '-i',
      input.path,
      '-ss',
      startSec,
      '-t',
      durationSec,
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
      debugPrint('ReelVideoTrimmer FFmpeg failed: $logs');
      try {
        final f = File(outPath);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
      throw Exception('Could not trim video');
    }

    return File(outPath);
  }
}
