import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Prepares a 360 master for R2 without changing the picture.
///
/// Faststart only moves the MP4 header to the front so playback can begin
/// before the whole file downloads. If that copy fails, the original file is
/// uploaded instead.
class VrVideoPrepare {
  VrVideoPrepare._();

  static Future<File> faststartCopy(File input) async {
    if (!await input.exists()) {
      throw StateError('Video file was not found.');
    }
    final dir = await getTemporaryDirectory();
    final outPath = '${dir.path}/vy_vr_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final session = await FFmpegKit.executeWithArguments(<String>[
      '-y',
      '-i',
      input.path,
      '-c',
      'copy',
      '-movflags',
      '+faststart',
      outPath,
    ]);
    final code = await session.getReturnCode();
    final out = File(outPath);
    if (!ReturnCode.isSuccess(code) || !await out.exists() || await out.length() <= 0) {
      debugPrint('VrVideoPrepare faststart skipped; uploading the original file.');
      if (await out.exists()) {
        await out.delete().catchError((_) => out);
      }
      return input;
    }
    return out;
  }

  /// One JPEG frame from the video, used as the post thumbnail.
  static Future<File> thumbnailJpeg(File video) async {
    final dir = await getTemporaryDirectory();
    final outPath = '${dir.path}/vy_vr_thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final session = await FFmpegKit.executeWithArguments(<String>[
      '-y',
      '-ss',
      '0',
      '-i',
      video.path,
      '-frames:v',
      '1',
      '-vf',
      'scale=min(1280,iw):-2',
      '-q:v',
      '3',
      outPath,
    ]);
    return _requireJpeg(
      session,
      outPath,
      'Could not create a preview image for this video.',
    );
  }

  /// Gallery cover images are normalized to JPEG before they are stored.
  static Future<File> coverJpeg(File image) async {
    final dir = await getTemporaryDirectory();
    final outPath = '${dir.path}/vy_vr_cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final session = await FFmpegKit.executeWithArguments(<String>[
      '-y',
      '-i',
      image.path,
      '-frames:v',
      '1',
      '-vf',
      'scale=min(1280,iw):-2',
      '-q:v',
      '3',
      outPath,
    ]);
    return _requireJpeg(session, outPath, 'Could not use that cover image.');
  }

  static Future<File> _requireJpeg(
    FFmpegSession session,
    String outPath,
    String failure,
  ) async {
    final code = await session.getReturnCode();
    final out = File(outPath);
    if (!ReturnCode.isSuccess(code) || !await out.exists() || await out.length() <= 0) {
      if (await out.exists()) {
        await out.delete().catchError((_) => out);
      }
      throw Exception(failure);
    }
    return out;
  }
}
