# `android/app/libs/` — local (uncommitted) AARs

This folder holds proprietary local libraries that are **not** committed to git (they are large and
license-restricted). `android/app/build.gradle.kts` consumes everything here via:

```kotlin
implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.aar", "*.jar"))))
```

## VITURE XR SDK (required for the XR viewer feature)

The head-tracked 360 viewer for **VITURE Luma XR** glasses depends on the VITURE Android SDK
(Java package `com.viture.sdk`, class `com.viture.sdk.ArManager`). It ships as a single AAR.

1. Register / sign in at **https://www.viture.com/developer** and download the Android SDK.
2. Drop the AAR here, e.g. `android/app/libs/VITURE-SDK-1.0.6.aar` (exact filename/version may differ).
3. Rebuild. Gradle links it automatically via the `fileTree` above — no version string to edit.

Until the AAR is present, the `com.viture.sdk.*` imports in
`android/app/src/main/kotlin/com/vyooo/viture/` will not resolve and the app will not compile. That is
expected on a checkout without the SDK.

### Notes
- **No Unity.** This is a plain Android AAR — no game engine, no extra Gradle plugin.
- **minSdk**: the SDK targets Android API **28+**. This project is already at `minSdk = 29`, so no bump
  is needed.
- **ABI**: if the AAR bundles native `.so`s that clash with Agora/Insta360 (e.g. `libc++_shared.so`),
  add a `pickFirsts`/`excludes` entry in the `packaging { jniLibs { … } }` block of
  `build.gradle.kts` (an Insta360 example is already there).
- Do **not** commit the AAR. The `.gitignore` in this folder enforces that.
