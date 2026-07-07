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
import com.arashivision.insta360.basemedia.ui.player.capture.IMediaFrameCallback
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
    private var warmRefreshDone = false
    private val extractWidth = (creationParams?.get("width") as? Int) ?: 1920
    private val extractHeight = (creationParams?.get("height") as? Int) ?: 960

    init {
        active = this
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
        if (active === this) active = null
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
        // First open only: signal "warming" so the UI holds its overlay until the warm refresh done.
        if (!warmRefreshDone) emitPreviewState("warming")
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
            val w = player.width
            val h = player.height
            Log.i(TAG, "onOpened → prepare+play (live panorama, view ${w}x$h)")
            // Match the render aspect to the actual (portrait) view so the sphere projection isn't
            // stretched — without this the SDK renders for a default aspect and the surface squishes
            // it vertically (objects look too short / extra cropping at the stitch seam).
            val params = buildCaptureParams()
            if (w > 0 && h > 0) params.setScreenRatio(w, h)
            player.prepare(params)
            // We don't override stitchType: the live preview already defaults to AI_FLOW (the SDK's
            // best). Near-seam overlap on close objects is binocular parallax — no setting fixes it.
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
        Log.i(TAG, "onFirstFrameRender → switch to interactive sphere")
        enableInteractiveView()
        // Post warm-up render → the stitch is correct, tell Flutter to drop the overlay; otherwise
        // this is the first (overlapping) render → trigger the warm refresh.
        if (warmRefreshDone) emitPreviewState("ready") else scheduleWarmRefresh()
    }

    private fun emitPreviewState(state: String) {
        try {
            onPreviewState?.invoke(state)
        } catch (t: Throwable) {
            Log.e(TAG, "emitPreviewState error", t)
        }
    }

    /**
     * The first preview after a camera (re)connect stitches from not-yet-warm calibration, so
     * seam objects overlap; a manual "leave and return" fixes it by re-initing against the now-warm
     * camera. We do that automatically, once per mount, via [warmRefresh].
     */
    private fun scheduleWarmRefresh() {
        if (warmRefreshDone || disposed) return
        warmRefreshDone = true
        player.postDelayed({ warmRefresh() }, WARM_REFRESH_DELAY_MS)
    }

    private fun warmRefresh() {
        if (disposed) return
        Log.i(TAG, "warmRefresh → restart preview stream to rebuild stitch from warm calibration")
        val mgr = InstaCameraManager.getInstance()
        try {
            player.stopExtractMediaFrame()
        } catch (t: Throwable) {
            Log.e(TAG, "warmRefresh stopExtract error", t)
        }
        try {
            mgr.setPipeline(null)
            mgr.closePreviewStream()
        } catch (t: Throwable) {
            Log.e(TAG, "warmRefresh close error", t)
        }
        // Reopen after a short beat so the close settles; onOpened re-fires and re-runs prepare →
        // play → sphere → extract (warmRefreshDone stays true → no re-trigger loop).
        player.postDelayed({
            if (disposed) return@postDelayed
            try {
                mgr.startPreviewStream(InstaCameraManager.PREVIEW_TYPE_NORMAL)
            } catch (t: Throwable) {
                Log.e(TAG, "warmRefresh reopen error", t)
            }
        }, WARM_REFRESH_REOPEN_GAP_MS)
    }

    /**
     * Switch the player to the interactive panoramic ("normal") projection. The native gesture
     * system is left OFF — touch events don't reliably reach an embedded platform view, so the host
     * drag is captured on the Flutter side and applied via [applyOrientation] ([setYaw]/[setPitch]).
     */
    private fun enableInteractiveView() {
        try {
            player.switchNormalMode()
            player.isGestureEnabled = false
        } catch (t: Throwable) {
            Log.e(TAG, "enableInteractiveView failed", t)
        }
    }

    /** Apply an absolute (yaw, pitch) in degrees to the live view, on the player's thread. */
    private fun applyOrientationInternal(yaw: Float, pitch: Float) {
        if (disposed) return
        player.post {
            if (disposed) return@post
            try {
                player.setYaw(yaw)
                player.setPitch(pitch)
            } catch (t: Throwable) {
                Log.e(TAG, "applyOrientation failed", t)
            }
        }
    }

    override fun onLoadingFinish() {
        if (disposed) return
        Log.i(TAG, "onLoadingFinish → setPipeline + startExtractMediaFrame ${extractWidth}x$extractHeight")
        // Connect the camera stream to the player so it renders the live interactive view.
        InstaCameraManager.getInstance().setPipeline(player.pipeline)
        // Extract the stitched ERP as MediaFrames for the transmit path:
        //   startExtractMediaFrame → Insta360FrameSink.submit → frames() → _pushInstaFrame → Agora.
        // EMPIRICAL: this tests whether extraction can coexist with the interactive sphere render.
        // Historically it aborted under the AUTO/normal render (extract worked only in flat
        // PLANE_STITCH). If this crashes on-device, fall back to a flat extract render for broadcast.
        try {
            player.startExtractMediaFrame(
                extractWidth,
                extractHeight,
                EXTRACT_FPS,
                EXTRACT_QUEUE,
                IMediaFrameCallback { mediaFrame ->
                    mediaFrame?.let { Insta360FrameSink.submit(it) }
                },
            )
        } catch (t: Throwable) {
            Log.e(TAG, "startExtractMediaFrame failed", t)
        }
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
            .setGestureEnabled(false)
    }

    companion object {
        private const val TAG = "Insta360PreviewView"
        private const val EXTRACT_FPS = 60
        private const val EXTRACT_QUEUE = 32

        /** Delay after the first frame before the one-shot warm-refresh stream restart. */
        private const val WARM_REFRESH_DELAY_MS = 1200L

        /** Gap between closing and reopening the preview stream during the warm refresh. */
        private const val WARM_REFRESH_REOPEN_GAP_MS = 350L

        /** The currently-mounted preview (only one exists at a time). */
        @Volatile private var active: Insta360PreviewView? = null

        /**
         * Host preview lifecycle signal for Flutter: "warming" while establishing, "ready" once the
         * corrected view shows. Wired by [Insta360Bridge] to its event channel.
         */
        @Volatile var onPreviewState: ((String) -> Unit)? = null

        /** Point the live interactive view at an absolute (yaw, pitch) in degrees. No-op if none. */
        fun applyOrientation(yaw: Float, pitch: Float) {
            active?.applyOrientationInternal(yaw, pitch)
        }
    }
}
