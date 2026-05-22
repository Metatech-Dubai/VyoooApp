/// Optional custom thumbnail URL for profile grid tiles only.
abstract final class ProfileGridThumbnail {
  ProfileGridThumbnail._();

  static String fromReel(Map<String, dynamic> reel) {
    return (reel['profileGridThumbnailUrl'] as String? ?? '').trim();
  }
}
