package com.vyooo

import android.os.Bundle
import androidx.core.view.WindowCompat
import com.vyooo.insta360.Insta360Bridge
import com.vyooo.insta360.Insta360PreviewViewFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var insta360Bridge: Insta360Bridge? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // FlutterActivity is not a ComponentActivity — use WindowCompat (Android 15+ edge-to-edge).
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Insta360 capture foundation (Phase 0). Additive; does not affect existing plugins.
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        insta360Bridge = Insta360Bridge(applicationContext, messenger)
        flutterEngine.platformViewsController.registry
            .registerViewFactory("vyooo/insta360_preview", Insta360PreviewViewFactory())
    }

    override fun onDestroy() {
        insta360Bridge?.dispose()
        insta360Bridge = null
        super.onDestroy()
    }
}
