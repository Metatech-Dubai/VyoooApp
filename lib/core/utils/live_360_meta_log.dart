import 'package:flutter/foundation.dart';

import '../models/live_stream_model.dart';
import '../widgets/live_stream_gyro_video_view.dart';
import 'live_360_video.dart';

/// Debug logging for live 360° stream metadata (filter logs with `[Live360Meta]`).
class Live360MetaLog {
  Live360MetaLog._();

  static String? _lastKey;

  static void log({
    required String source,
    required LiveStreamModel stream,
    int? remoteVideoWidth,
    int? remoteVideoHeight,
    bool motionActive = true,
    bool gyroEnabled = true,
    LiveGyroProjectionMode? resolvedMode,
  }) {
    final mode = resolvedMode ??
        resolveLiveGyroProjectionMode(
          stream: stream,
          remoteVideoWidth: remoteVideoWidth,
          remoteVideoHeight: remoteVideoHeight,
        );

    final aspect = (remoteVideoWidth != null &&
            remoteVideoHeight != null &&
            remoteVideoHeight > 0)
        ? (remoteVideoWidth / remoteVideoHeight).toStringAsFixed(3)
        : 'n/a';

    final autoDetect = remoteVideoWidth != null &&
        remoteVideoHeight != null &&
        isLikelyEquirectangularLiveVideo(remoteVideoWidth, remoteVideoHeight);

    final key =
        '$source|${stream.id}|${stream.is360Live}|${stream.projectionType.firestoreValue}|'
        '${remoteVideoWidth ?? 0}x${remoteVideoHeight ?? 0}|$motionActive|$gyroEnabled|${mode.name}';
    if (_lastKey == key) return;
    _lastKey = key;

    debugPrint(
      '[Live360Meta] source=$source '
      'streamId=${stream.id} '
      'channel=${stream.agoraChannelName} '
      'status=${stream.status.name} '
      'is360Live=${stream.is360Live} '
      'projectionType=${stream.projectionType.firestoreValue} '
      'isImmersive360Live=${stream.isImmersive360Live} '
      'remoteVideo=${remoteVideoWidth ?? '?'}x${remoteVideoHeight ?? '?'} '
      'aspect=$aspect '
      'autoDetect2x1=$autoDetect '
      'motionActive=$motionActive '
      'gyroEnabled=$gyroEnabled '
      'resolvedMode=${mode.name} '
      'badge=${mode == LiveGyroProjectionMode.equirectangular ? (_badgeLabel(motionActive, gyroEnabled)) : 'Live'}',
    );
  }

  static String _badgeLabel(bool motionActive, bool gyroEnabled) {
    if (gyroEnabled && motionActive) return '360° Gyro';
    return '360° Live';
  }

  /// Force the next [log] call to print even if fields are unchanged.
  static void resetDedupe() {
    _lastKey = null;
  }
}
