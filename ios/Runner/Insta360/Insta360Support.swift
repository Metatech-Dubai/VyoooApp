import Foundation
import INSCameraSDK
import INSCameraServiceSDK

/// Single source of truth for whether the Insta360 capture feature can run on this device,
/// plus one-time SDK setup. iOS mirror of the Android `Insta360Support` object +
/// `VyoooApplication.onCreate()` init (android/.../com/vyooo/VyoooApplication.kt).
///
/// The Insta360 iOS SDK ships arm64 dynamic frameworks only — it cannot run on the iOS
/// **simulator** (no arm64-simulator slice is embedded by our podspec by default) and needs a
/// physical camera. On unsupported configurations we degrade to "feature unavailable" so the rest
/// of the app keeps working, exactly like Android.
enum Insta360Support {

    /// arm64 device (not simulator). The SDK's frameworks are device-only.
    static let isArm64Device: Bool = {
        #if targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }()

    /// iOS 15+ (matches the Runner deployment target / Podfile `platform :ios, '15.0'`).
    static let isOsOk: Bool = {
        if #available(iOS 15.0, *) { return true }
        return false
    }()

    static var isSupported: Bool { isArm64Device && isOsOk }

    /// Set if SDK setup threw/failed; surfaced to Flutter for diagnostics (mirrors Android `initError`).
    static var initError: String?

    private static var didSetup = false

    /// Call once at app launch (from `AppDelegate`). Idempotent.
    ///
    /// The README requires `[[INSCameraManager sharedManager] setup]` at launch so the SDK starts
    /// listening for cameras. We also `setup` the USB (External Accessory) manager so an MFi camera
    /// plugged over Lightning/USB is detected. The Wi-Fi (socket) manager is set up lazily on a
    /// `connect(type: wifi)` (see `Insta360Bridge`), matching the SDK sample
    /// (`RootViewController+Sections.swift`).
    static func setupIfSupported() {
        guard isSupported else {
            NSLog("[Insta360] SDK skipped (unsupported: arm64Device=\(isArm64Device), osOk=\(isOsOk))")
            return
        }
        guard !didSetup else { return }
        didSetup = true
        // `setup` must run on the main thread (it wires up run-loop sources / EA sessions).
        INSCameraManager.sharedManager().setup()
        INSCameraManager.usbManager().setup()
        NSLog("[Insta360] SDK initialised (shared + usb managers)")
    }
}
