package com.vyooo.insta360

import android.content.Context
import android.util.Log
import android.view.View
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.arashivision.sdkcamera.camera.InstaCameraManager
import com.arashivision.sdkcamera.camera.callback.ICameraOperateCallback
import com.arashivision.sdkcamera.camera.callback.ICaptureSupportConfigCallback
import com.arashivision.sdkcamera.camera.callback.IPreviewStatusListener
import com.arashivision.sdkmedia.player.capture.CaptureParamsBuilder
import com.arashivision.sdkmedia.player.capture.InstaCapturePlayerView
import com.arashivision.sdkmedia.player.listener.PlayerViewListener
import io.flutter.plugin.platform.PlatformView

/**
 * PlatformView hosting the SDK's [InstaCapturePlayerView]. While mounted it:
 *  1. opens the camera preview stream,
 *  2. renders an **interactive panoramic sphere** the host can look around — touch-drag to pan,
 *     pinch to zoom (handled natively by the player's gesture system),
 *  3. on render-ready, attaches the camera pipeline so the player renders the live feed.
 *
 * Requires the camera to already be connected (via [Insta360Bridge.connect]). Unmounting stops
 * extraction and closes the preview stream.
 *
 * Lifecycle/SDK calls mirror the SDK demo (`CaptureActivity` / `CaptureViewModel`) to stay binary-
 * compatible with the linked 1.10.1 AAR.
 */
class Insta360PreviewView(
    context: Context,
    creationParams: Map<String, Any?>?,
) : PlatformView, LifecycleOwner, IPreviewStatusListener, PlayerViewListener {

    private val lifecycleRegistry = LifecycleRegistry(this)
    override val lifecycle: Lifecycle get() = lifecycleRegistry

    private val player = InstaCapturePlayerView(context)
    private var disposed = false

    init {
        lifecycleRegistry.currentState = Lifecycle.State.RESUMED
        player.setLifecycle(lifecycleRegistry)
        player.setPlayerViewListener(this)

        val mgr = InstaCameraManager.getInstance()
        mgr.setPreviewStatusChangedListener(this)
        // The camera is already connected (Dart mounts this view only once connected). Run the SDK's
        // required pre-preview init before starting the stream: fetchCameraOptions → ensure panorama
        // (dual-sensor) → initCameraSupportConfig → setStreamEncode → startPreviewStream. Skipping
        // these leaves the stream open but producing no decodable frames.
        beginPreviewSequence(mgr)
    }

    private fun beginPreviewSequence(mgr: InstaCameraManager) {
        Log.i(TAG, "preview init: fetchCameraOptions")
        mgr.fetchCameraOptions(operate("fetchCameraOptions") { ensurePanorama(mgr) })
    }

    private fun ensurePanorama(mgr: InstaCameraManager) {
        if (disposed) return
        if (mgr.isCameraDualSensorMode) {
            Log.i(TAG, "preview init: already dual-sensor")
            initSupportConfig(mgr)
        } else {
            Log.i(TAG, "preview init: switchPanoramaSensorMode")
            mgr.switchPanoramaSensorMode(operate("switchPanoramaSensorMode") { initSupportConfig(mgr) })
        }
    }

    private fun initSupportConfig(mgr: InstaCameraManager) {
        if (disposed) return
        Log.i(TAG, "preview init: initCameraSupportConfig")
        mgr.initCameraSupportConfig(object : ICaptureSupportConfigCallback {
            override fun onComplete() = beginPreview(mgr)
            override fun onFailed(s: String) {
                Log.e(TAG, "initCameraSupportConfig failed: $s; continuing")
                beginPreview(mgr)
            }
        })
    }

    private fun beginPreview(mgr: InstaCameraManager) {
        if (disposed) return
        Log.i(TAG, "preview init: startPreviewStream")
        // NOTE: setStreamEncode() must be called *after* the stream opens (in onOpened) — before
        // it, the SDK's StartStreamingParam is still null and setStreamEncode() NPEs.
        mgr.startPreviewStream(InstaCameraManager.PREVIEW_TYPE_NORMAL)
    }

    /** An [ICameraOperateCallback] that always advances to [next] (logging non-fatal failures). */
    private fun operate(tag: String, next: () -> Unit) = object : ICameraOperateCallback {
        override fun onSuccessful() = next()
        override fun onFailed() {
            Log.e(TAG, "$tag failed; continuing")
            next()
        }
        override fun onCameraConnectError() {
            Log.e(TAG, "$tag: camera connect error")
        }
    }

    override fun getView(): View = player

    override fun dispose() {
        if (disposed) return
        disposed = true
        try {
            player.destroy()
            val mgr = InstaCameraManager.getInstance()
            mgr.setPreviewStatusChangedListener(null)
            mgr.setPipeline(null)
            mgr.closePreviewStream()
        } catch (t: Throwable) {
            Log.e(TAG, "dispose error", t)
        }
        Insta360FrameSink.streamingEnabled = false
        lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
    }

    // ── IPreviewStatusListener ────────────────────────────────────────────────
    override fun onOpening() {}

    override fun onOpened() {
        if (disposed) return
        // The preview stream is now open → safe to set the stream encode (the demo calls this in its
        // openPreviewStream success callback; calling it earlier NPEs on a null StartStreamingParam).
        try {
            InstaCameraManager.getInstance().setStreamEncode()
            Log.i(TAG, "onOpened → setStreamEncode")
        } catch (t: Throwable) {
            Log.e(TAG, "setStreamEncode error", t)
        }
        player.post {
            if (disposed) return@post
            Log.i(TAG, "onOpened → prepare+play (live panorama, view ${player.width}x${player.height})")
            player.prepare(buildCaptureParams())
            player.play()
            player.keepScreenOn = true
        }
    }

    override fun onIdle() {}

    override fun onError() {
        Log.e(TAG, "preview stream error")
    }

    // ── PlayerViewListener ────────────────────────────────────────────────────
    override fun onFirstFrameRender() {
        if (disposed) return
        Log.i(TAG, "onFirstFrameRender → switch to interactive sphere + enable touch gestures")
        enableInteractiveView()
    }

    /**
     * Switch the player to the interactive panoramic ("normal") projection and turn on its built-in
     * gestures so the host can drag to look around and pinch to zoom. Safe to call once rendering.
     */
    private fun enableInteractiveView() {
        try {
            player.switchNormalMode()
            player.isGestureEnabled = true
            player.isGestureHorizontalEnabled = true
            player.isGestureVerticalEnabled = true
            player.isGestureZoomEnabled = true
        } catch (t: Throwable) {
            Log.e(TAG, "enableInteractiveView failed", t)
        }
    }

    override fun onLoadingFinish() {
        if (disposed) return
        Log.i(TAG, "onLoadingFinish → setPipeline (interactive render)")
        // Connect the camera stream to the player so it renders the live interactive view.
        InstaCameraManager.getInstance().setPipeline(player.pipeline)
        // NOTE: media-frame extraction (startExtractMediaFrame → Insta360FrameSink, the transmit
        // path) is intentionally NOT started here. The SDK's extract SequenceSource aborts when the
        // player renders the interactive AUTO view (it only works with the flat PLANE_STITCH render).
        // Extraction belongs to the streaming feature and needs its own offscreen path — out of
        // scope for the interactive host preview.
    }

    override fun onReleaseCameraPipeline() {
        InstaCameraManager.getInstance().setPipeline(null)
    }

    /**
     * The SDK's live-preview params (v1 builder). The interactive panoramic render needs the camera's
     * lens calibration (`mediaOffset*`) and the live flag — the flat `PLANE_STITCH` (V2) path didn't,
     * which is why it never crashed. Stabilization is off: it relies on gyro frame interpolation a
     * live feed can't supply (the host drives the view by touch). Mirrors the SDK demo's setup.
     */
    private fun buildCaptureParams(): CaptureParamsBuilder {
        val mgr = InstaCameraManager.getInstance()
        return CaptureParamsBuilder()
            .setCameraType(mgr.cameraType)
            .setMediaOffset(mgr.mediaOffset)
            .setMediaOffsetV2(mgr.mediaOffsetV2)
            .setMediaOffsetV3(mgr.mediaOffsetV3)
            .setCameraSelfie(mgr.isCameraSelfie)
            .setGyroTimeStamp(mgr.gyroTimeStamp)
            .setLive(true)
            .setStabEnabled(false)
            .setGestureEnabled(true)
    }

    private companion object {
        const val TAG = "Insta360PreviewView"
    }
}
