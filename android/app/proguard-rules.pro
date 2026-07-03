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

# CallKit incoming (video/audio calls)
-keep class com.hiennv.flutter_callkit_incoming.** { *; }

# Native 360° VR player (ExoPlayer Media3 + spherical surface)
-keep class com.kino.video_360.** { *; }
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**

# Chat voice notes (audio_waveforms) — ExoPlayer 2 core only; UI module excluded at Gradle level
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**
