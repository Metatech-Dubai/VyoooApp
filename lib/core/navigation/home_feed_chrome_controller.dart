import 'package:flutter/foundation.dart';

/// Bridges home reel playback progress into [AppBottomNavigation] feed chrome.
class HomeFeedChromeController {
  HomeFeedChromeController();

  /// `null` hides the chrome progress bar; otherwise 0–1 playback position.
  final ValueNotifier<double?> progress = ValueNotifier<double?>(null);

  /// Seek requests from the chrome progress bar scrubber.
  final ValueNotifier<double?> seekFraction = ValueNotifier<double?>(null);

  /// True while the user is dragging the live progress scrubber.
  final ValueNotifier<bool> isLiveScrubbing = ValueNotifier<bool>(false);

  /// Cached frame bytes for the live scrub preview thumbnail.
  final ValueNotifier<Uint8List?> liveSeekPreviewBytes =
      ValueNotifier<Uint8List?>(null);

  /// Formatted elapsed-time label for the live scrub preview (e.g. "19:47").
  final ValueNotifier<String?> liveSeekPreviewTimeLabel =
      ValueNotifier<String?>(null);

  /// Fallback image URL when no cached frame exists yet.
  final ValueNotifier<String?> liveSeekPreviewFallbackUrl =
      ValueNotifier<String?>(null);

  void dispose() {
    progress.dispose();
    seekFraction.dispose();
    isLiveScrubbing.dispose();
    liveSeekPreviewBytes.dispose();
    liveSeekPreviewTimeLabel.dispose();
    liveSeekPreviewFallbackUrl.dispose();
  }
}
