/// Centralized deep-link / share URL builder.
///
/// Sharing produces a single, human-readable HTTPS **universal link**
/// (`https://www.vyooo.com/u/<username>`), exactly like Instagram
/// (`https://www.instagram.com/<username>`). When the app is installed and the
/// associated domain is verified, the OS opens the app directly; otherwise the
/// `/u/<username>` web page opens the app via the custom scheme or sends the
/// user to the store. The raw `vyooo://` scheme is kept only as an internal
/// bridge target and is never shown in share text.
class DeepLinkConfig {
  DeepLinkConfig._();

  static const String webHost = 'www.vyooo.com';
  static const String customScheme = 'vyooo';

  /// Path prefix for public profile links: `https://www.vyooo.com/u/<ref>`.
  static const String profilePathPrefix = 'u';

  /// Path prefix for public reel links: `https://www.vyooo.com/r/<id>`.
  static const String reelPathPrefix = 'r';

  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.vyooo';

  /// Set when App Store listing id is known (Firestore `iosAppStoreId` or here).
  static const String? iosAppStoreUrl = null;

  /// Legacy web bridge path (`/open?profile=`/`?reel=`). Still parsed for
  /// backward compatibility with links shared before the `/u` + `/r` rollout.
  static const String webOpenPath = '/open';

  /// Strip a leading `@`, surrounding spaces and any internal whitespace from a
  /// username so it is safe to place in a URL path. Mirrors
  /// `UsernameValidation.normalize` (whitespace only — usernames are
  /// case-sensitive on the server, so case is preserved in the link).
  static String normalizeUsername(String? raw) {
    var value = (raw ?? '').trim();
    if (value.startsWith('@')) value = value.substring(1);
    return value.replaceAll(RegExp(r'\s'), '');
  }

  // ---------------------------------------------------------------------------
  // Reels
  // ---------------------------------------------------------------------------

  /// Canonical public reel link: `https://www.vyooo.com/r/<reelId>`.
  static Uri reelWebUri(String reelId) {
    return Uri.https(webHost, '/$reelPathPrefix/${reelId.trim()}');
  }

  static Uri reelAppUri(String reelId) {
    return Uri(
      scheme: customScheme,
      host: 'reel',
      pathSegments: [reelId],
    );
  }

  // ---------------------------------------------------------------------------
  // Profiles
  // ---------------------------------------------------------------------------

  /// Canonical public profile link, preferring the human-readable username
  /// (`https://www.vyooo.com/u/amyvictoriakenyon`). Falls back to the uid only
  /// when no username is available.
  static Uri profileWebUri({String? username, String? uid}) {
    final handle = normalizeUsername(username);
    final ref = handle.isNotEmpty ? handle : (uid ?? '').trim();
    return Uri.https(webHost, '/$profilePathPrefix/$ref');
  }

  static Uri profileAppUri(String profileRef) {
    return Uri(
      scheme: customScheme,
      host: 'profile',
      pathSegments: [profileRef.trim()],
    );
  }

  // ---------------------------------------------------------------------------
  // Share copy
  // ---------------------------------------------------------------------------

  /// Clean, Instagram-style share text: a short caption followed by a single
  /// HTTPS profile link. Store / install fallback is handled by the web page,
  /// so the message stays a single tappable link (no raw scheme, no store dump).
  static String profileShareMessage({
    required String profileRef,
    String? username,
  }) {
    final handle = normalizeUsername(username);
    final link = profileWebUri(username: username, uid: profileRef).toString();
    final caption =
        handle.isNotEmpty ? '@$handle on Vyooo' : 'Check out this profile on Vyooo';
    return '$caption\n$link';
  }

  /// Clean, Instagram-style reel share text: short caption + single HTTPS link.
  static String reelShareMessage({required String reelId, String? caption}) {
    final link = reelWebUri(reelId).toString();
    final headline = (caption ?? '').trim().isNotEmpty
        ? caption!.trim()
        : 'Watch this on Vyooo';
    return '$headline\n$link';
  }
}
