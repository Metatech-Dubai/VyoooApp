/// Legal URLs used in-app (subscription screen, onboarding) and should match
/// App Store Connect: Privacy Policy field + Terms link in the App Description
/// (or a custom EULA in App Information).
class AppLinks {
  AppLinks._();

  static const String termsOfUse = 'https://www.vyooo.com/terms';
  static const String privacyPolicy = 'https://www.vyooo.com/privacy';

  /// Public TestFlight beta (manual override only; production fallback is the
  /// App Store listing below).
  static const String iosTestFlightJoin =
      'https://testflight.apple.com/join/NjQVQ2nD';

  /// Production App Store listing for VyooO (bundle id com.vyooo).
  /// Fallback when Firestore `ios.updateUrl` / `iosAppStoreId` are unset.
  static const String iosAppStore = 'https://apps.apple.com/app/id6757733269';

  /// Apple’s standard Licensed Application EULA. If you rely on it, Apple expects
  /// a functional link in App Store metadata (often in the App Description).
  /// See: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
  static const String appleStandardLicensedApplicationEula =
      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
}
