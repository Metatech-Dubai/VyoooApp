plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.vyooo"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.vyooo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Insta360 SDK (sdkcamera/sdkmedia) native libs target API 29+; raised from the Flutter
        // default to satisfy the SDK. The Insta360 capture feature is additionally runtime-gated to
        // arm64 devices (SDK ships arm64-v8a only). Agora RTC needs only API 21+.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Phone/tablet devices only; skip x86/x86_64 to avoid broken emulator CMake on some NDK setups.
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }
    }

    packaging {
        jniLibs {
            // Agora RTC and the Insta360 SDK both bundle libc++_shared.so — take the first to avoid
            // a duplicate-.so packaging failure.
            pickFirsts += listOf(
                "lib/arm64-v8a/libc++_shared.so",
                "lib/armeabi-v7a/libc++_shared.so",
            )
            // Insta360 SNPE ships Qualcomm DSP skeleton libs for many Hexagon versions; the live
            // capture path does not use on-device NN inference.
            excludes += listOf(
                "lib/arm64-v8a/libSnpeHtpV68Skel.so",
                "lib/arm64-v8a/libSnpeHtpV69Skel.so",
                "lib/arm64-v8a/libSnpeHtpV73Skel.so",
                "lib/arm64-v8a/libSnpeHtpV75Skel.so",
                "lib/arm64-v8a/libSnpeHtpV79Skel.so",
                "lib/arm64-v8a/libcalculator_skel.so",
            )
        }
        resources {
            excludes += listOf("META-INF/rxjava.properties")
        }
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                val storeFilePath = keystoreProperties["storeFile"] as String
                storeFile = file(storeFilePath)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use Play upload key when android/key.properties exists.
            // Fallback to debug only for local/dev builds.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.core:core-splashscreen:1.0.1")

    // Insta360 capture SDK — camera control + on-device stitched-preview/media (frame extraction).
    // Transitive: okhttp 3.8.1, gson 2.6.2, rxandroid 2.1.1 (mavenCentral) + insbase/basecamera/basemedia/snpe (Insta360 repo).
    implementation("com.arashivision.sdk:sdkcamera:1.10.1")
    implementation("com.arashivision.sdk:sdkmedia:1.10.1")
}
