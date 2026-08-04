# Vyooo — release / Play builds (Flutter enables R8 for release by default).
#
# Without these rules, Firebase fails at startup with:
#   PlatformException(channel-error, Unable to establish connection on channel:
#   "dev.flutter.pigeon.firebase_core_platform_interface.FirebaseCoreHostApi.initializeCore" ...)
# because R8 removes or breaks the Pigeon JNI / host classes.
#
# References: https://github.com/firebase/flutterfire/issues/17799

# FlutterFire + all Firebase Pigeon host APIs used by plugins
-keep class dev.flutter.pigeon.** { *; }
-keep class io.flutter.plugins.firebase.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# FFmpegKit (also JNI-heavy; plugin ships rules but app merge is the safe net)
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-dontwarn com.antonkarpenko.ffmpegkit.**

# Insta360 / Arashivision SDK (AAR references optional onestreamtarget classes not
# always present on the classpath; R8 fails release minify without these).
-keep class com.arashivision.** { *; }
-keep interface com.arashivision.** { *; }
-dontwarn com.arashivision.**
-dontwarn com.arashivision.onestreamtarget.OneStreamTarget$DualShadowObj
-dontwarn com.arashivision.onestreamtarget.OneStreamTarget$ShadowObj
-dontwarn com.arashivision.onestreamtarget.OneStreamTarget$StreamExtra
-dontwarn com.arashivision.onestreamtarget.OneStreamTarget
-dontwarn com.arashivision.onestreamtarget.StreamShadowTexture$onShadowTexutureListener
-dontwarn com.arashivision.onestreamtarget.StreamShadowTexture
