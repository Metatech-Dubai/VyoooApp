import Flutter
import UIKit

#if DEBUG && !targetEnvironment(simulator)
#error("Physical iPhone Debug mode is blocked for Vyooo because Agora/Iris can crash with EXC_BAD_ACCESS. Use Profile/Release (flutter run --profile/--release).")
#endif

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// Retained for the app's lifetime — owns the Insta360 method/event channels.
  private var insta360Bridge: Insta360Bridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // ── Insta360 capture bridge ───────────────────────────────────────────────
    // One-time SDK setup (mirrors Android VyoooApplication.onCreate). Guarded so an unsupported
    // configuration (simulator / <iOS 15) degrades to "feature unavailable" instead of crashing.
    Insta360Support.setupIfSupported()
    if let instaRegistrar = self.registrar(forPlugin: "Insta360") {
      insta360Bridge = Insta360Bridge(
        messenger: instaRegistrar.messenger(),
        textureRegistry: instaRegistrar.textures()
      )
      instaRegistrar.register(
        Insta360PreviewViewFactory(),
        withId: "vyooo/insta360_preview"
      )
    }

    guard let registrar = self.registrar(forPlugin: "VyoooDeferredNativePlugins") else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    let channel = FlutterMethodChannel(
      name: "vyooo/deferred_native_plugins",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "registerAgora" {
        guard let self else {
          result(FlutterError(code: "no_registry", message: nil, details: nil))
          return
        }
        AgoraDeferredRegistration.register(with: self)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
