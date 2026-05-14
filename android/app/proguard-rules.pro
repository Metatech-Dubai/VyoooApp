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
