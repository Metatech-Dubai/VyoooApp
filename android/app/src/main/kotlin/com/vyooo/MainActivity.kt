package com.vyooo

import android.app.NotificationManager
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)

        // After super.onCreate so NormalTheme is applied — calling this earlier can
        // surface a native title bar with android:label on some API/OEM combos.
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

        val notificationManager =
            getSystemService(NotificationManager::class.java) ?: return
        CallkitNotificationChannels.ensureCreated(notificationManager)
    }
}
