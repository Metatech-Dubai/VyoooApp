# Insta360 iOS SDK (vendored)

This folder holds the local CocoaPods pod that vendors the Insta360 iOS SDK (v1.9.2) into the
Runner app. The framework **binaries are not committed** (too large) — only `INSCameraSDK.podspec`
and this README are tracked.

## Setup (Mac, before `pod install`)

1. Copy the xcframeworks in:

   ```sh
   ios/scripts/install_insta360_sdk.sh /path/to/iOS_v1.9.2/INSCameraSDKSample-bluetooth/Frameworks
   ```

   (or set `INSTA360_IOS_SDK` to that folder and run the script with no args). This copies:
   - `INSCameraSDK.xcframework`
   - `INSCameraServiceSDK.xcframework`
   - `INSCoreMedia.xcframework`

2. Install pods:

   ```sh
   cd ios && pod install
   ```

CocoaPods embeds & code-signs the dynamic frameworks automatically (no manual Xcode "Embed & Sign").

See `../../Technical documentation/iOS SDK Integration — Setup & Build Guide (Insta360 1.9.2).md`
for the full procedure, Info.plist keys, entitlements, and the gaps/risks list.
