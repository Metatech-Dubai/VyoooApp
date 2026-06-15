package com.vyooo

import android.graphics.Color
import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // FlutterActivity is not a ComponentActivity — use WindowCompat (Android 15+ edge-to-edge).
        WindowCompat.setDecorFitsSystemWindows(window, false)
        if (Build.VERSION.SDK_INT < 35) {
            // Android 14 and below: theme default paints an opaque black system nav bar over
            // edge-to-edge content (black box under the app's bottom nav). Android 15+ enforces
            // transparent bars and deprecates these setters, so only apply below API 35.
            @Suppress("DEPRECATION")
            window.navigationBarColor = Color.TRANSPARENT
            @Suppress("DEPRECATION")
            window.statusBarColor = Color.TRANSPARENT
            if (Build.VERSION.SDK_INT >= 29) {
                window.isNavigationBarContrastEnforced = false
            }
        }
        super.onCreate(savedInstanceState)
    }
}
