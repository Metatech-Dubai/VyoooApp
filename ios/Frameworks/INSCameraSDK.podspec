#
# Local development pod that vendors the Insta360 iOS SDK (v1.9.2) into the Runner app.
#
# The three dynamic xcframeworks are NOT committed to git (they are ~150 MB+ device-only, GBs with
# every slice + dSYMs). Run `ios/scripts/install_insta360_sdk.sh` on the Mac to copy them next to
# this podspec BEFORE `pod install`. CocoaPods then embeds & code-signs them automatically, so no
# manual Xcode "Embed & Sign" step is required.
#
# Referenced from the Podfile as:  pod 'INSCameraSDK', :path => 'Frameworks'
#
Pod::Spec.new do |s|
  s.name             = 'INSCameraSDK'
  s.version          = '1.9.2'
  s.summary          = 'Insta360 Camera SDK (vendored xcframeworks) for the Vyooo app.'
  s.description      = 'Vendors INSCameraSDK, INSCameraServiceSDK and INSCoreMedia dynamic ' \
                       'xcframeworks so the Runner target can talk to Insta360 cameras on iOS.'
  s.homepage         = 'https://www.insta360.com'
  s.license          = { :type => 'Proprietary', :text => 'Insta360 SDK — proprietary license.' }
  s.author           = { 'Insta360' => 'developer@insta360.com' }
  s.platform         = :ios, '15.0'

  # `:path` pods still require a source location; point at this directory.
  s.source           = { :path => '.' }

  # The vendored dynamic frameworks (must be present — see install_insta360_sdk.sh).
  s.vendored_frameworks = [
    'INSCameraSDK.xcframework',
    'INSCameraServiceSDK.xcframework',
    'INSCoreMedia.xcframework',
  ]

  # System frameworks / libs the SDK links against (declared for robustness; the dynamic
  # frameworks also carry their own load commands).
  s.frameworks = [
    'AVFoundation', 'CoreMedia', 'CoreVideo', 'VideoToolbox', 'AudioToolbox',
    'CoreImage', 'CoreGraphics', 'QuartzCore', 'GLKit', 'OpenGLES', 'Metal',
    'ExternalAccessory', 'CoreMotion', 'SystemConfiguration', 'UIKit', 'Foundation',
  ]
  s.libraries = ['c++', 'z', 'bz2', 'iconv']

  # These are prebuilt binaries — nothing to compile. The xcframeworks carry ios-arm64 and
  # ios-arm64-simulator slices only (no x86_64), so device + Apple-Silicon simulator build; an
  # Intel-Mac simulator cannot link the SDK (the feature is disabled at runtime on simulator anyway).
  s.requires_arc = true
end
