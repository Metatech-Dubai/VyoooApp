import '../models/live_stream_model.dart';
import '../widgets/live_stream_gyro_video_view.dart';

/// Minimum width:height for an incoming Agora frame to treat as equirectangular 360.
const double kLive360EquirectangularMinAspect = 1.75;
const double kLive360EquirectangularMaxAspect = 2.15;

/// True when [width]:[height] looks like a 2:1 equirectangular 360 frame.
bool isLikelyEquirectangularLiveVideo(int width, int height) {
  if (width <= 0 || height <= 0) return false;
  final aspect = width / height;
  return aspect >= kLive360EquirectangularMinAspect &&
      aspect <= kLive360EquirectangularMaxAspect;
}

/// Resolves how the viewer should map gyro onto the Agora texture.
LiveGyroProjectionMode resolveLiveGyroProjectionMode({
  required LiveStreamModel stream,
  int? remoteVideoWidth,
  int? remoteVideoHeight,
}) {
  if (stream.isImmersive360Live) {
    return LiveGyroProjectionMode.equirectangular;
  }
  if (remoteVideoWidth != null &&
      remoteVideoHeight != null &&
      isLikelyEquirectangularLiveVideo(remoteVideoWidth, remoteVideoHeight)) {
    return LiveGyroProjectionMode.equirectangular;
  }
  return LiveGyroProjectionMode.flat;
}
