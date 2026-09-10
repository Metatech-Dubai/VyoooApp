package com.vyooo

import android.os.Bundle
import androidx.core.view.WindowCompat
import com.vyooo.insta360.Insta360Bridge
import com.vyooo.insta360.Insta360PreviewViewFactory
import com.vyooo.viewer.ViewerSphereBridge
import com.vyooo.viewer.ViewerSphereViewFactory
import com.vyooo.viture.VitureBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var insta360Bridge: Insta360Bridge? = null
    private var vitureBridge: VitureBridge? = null
    private var viewerSphereBridge: ViewerSphereBridge? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // FlutterActivity is not a ComponentActivity — use WindowCompat (Android 15+ edge-to-edge).
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        // flutterEngine.renderer is the TextureRegistry for the processed-frame texture.
        insta360Bridge = Insta360Bridge(applicationContext, messenger, flutterEngine.renderer)
        flutterEngine.platformViewsController.registry
            .registerViewFactory("vyooo/insta360_preview", Insta360PreviewViewFactory())

        // VITURE XR viewer: head-tracking bridge + the GL sphere platform view + its frame/orientation
        // ingress channel. Channel/view names must match the Dart side (viture_service.dart,
        // viewer_sphere_view.dart).
        vitureBridge = VitureBridge(applicationContext, messenger)
        viewerSphereBridge = ViewerSphereBridge(messenger)
        flutterEngine.platformViewsController.registry
            .registerViewFactory("vyooo/viewer_sphere", ViewerSphereViewFactory())
    }

    override fun onDestroy() {
        insta360Bridge?.dispose()
        insta360Bridge = null
        vitureBridge?.dispose()
        vitureBridge = null
        viewerSphereBridge?.dispose()
        viewerSphereBridge = null
        super.onDestroy()
    }
}
