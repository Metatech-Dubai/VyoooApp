package com.vyooo

import android.app.NotificationManager
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.view.WindowCompat
import com.vyooo.insta360.Insta360Bridge
import com.vyooo.insta360.Insta360PreviewViewFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var insta360Bridge: Insta360Bridge? = null

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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        // flutterEngine.renderer is the TextureRegistry for the processed-frame texture.
        insta360Bridge = Insta360Bridge(applicationContext, messenger, flutterEngine.renderer)
        flutterEngine.platformViewsController.registry
            .registerViewFactory("vyooo/insta360_preview", Insta360PreviewViewFactory())
    }

    override fun onDestroy() {
        insta360Bridge?.dispose()
        insta360Bridge = null
        super.onDestroy()
    }
}
