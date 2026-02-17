// 🔴 IMPORTANT:
// Do NOT use hardcoded spacing anywhere in the project.
// Always use AppSpacing or AppPadding.
// This ensures consistent UI rhythm across the app.

/// 4pt grid spacing constants. Use for SizedBox(height: AppSpacing.xx) or padding values.
abstract final class AppSpacing {
  /// Extra small (e.g. caption to stats gap in feed)
  static const double xs = 4;

  /// Small (icon + text gap, username to caption)
  static const double sm = 8;

  /// Medium (between elements, item gap)
  static const double md = 16;

  /// Large (feed interaction button vertical spacing)
  static const double lg = 22;

  /// Extra large (section spacing)
  static const double xl = 24;

  /// Story row item spacing (12 = 3×4pt)
  static const double storyItem = 12;
}
