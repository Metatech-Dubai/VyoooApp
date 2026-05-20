/// Font family names registered in [pubspec.yaml].
///
/// Vyooo uses **DM Sans** app-wide. Bundled weights: 400, 500, 600, 700
/// (`DMSans-400.ttf` … `DMSans-700.ttf`). Prefer [AppTypography] or
/// [Theme.of(context).textTheme] — do not set [fontFamily] on screens.
abstract final class AppFonts {
  /// Default family for all UI (see [AppTheme.dark] `fontFamily`).
  static const String body = 'DM Sans';

  /// Alias of [body] — kept so existing `AppFonts.display` call sites stay valid.
  static const String display = body;
}
