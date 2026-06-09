package com.vyooo.insta360

import android.content.Context
import android.util.Log
import android.view.View
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.arashivision.insta360.basemedia.ui.player.capture.IMediaFrameCallback
import com.arashivision.sdkcamera.camera.InstaCameraManager
import com.arashivision.sdkcamera.camera.callback.ICameraOperateCallback
import com.arashivision.sdkcamera.camera.callback.ICaptureSupportConfigCallback
import com.arashivision.sdkcamera.camera.callback.IPreviewStatusListener
import com.arashivision.sdkmedia.params.RenderModel
import com.arashivision.sdkmedia.player.capture.CaptureParamsBuilderV2
import com.arashivision.sdkmedia.player.capture.InstaCapturePlayerView
import com.arashivision.sdkmedia.player.listener.PlayerViewListener
import io.flutter.plugin.platform.PlatformView

/**
 * PlatformView hosting the SDK's [InstaCapturePlayerView]. While mounted it:
 *  1. opens the camera preview stream,
 *  2. renders the stitched **equirectangular (ERP, 2:1)** panorama (PLANE_STITCH),
 *  3. on render-ready, attaches the camera pipeline and starts ARGB frame extraction → [Insta360FrameSink].
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
    private val extractWidth = (creationParams?.get("width") as? Int) ?: 1920
    private val extractHeight = (creationParams?.get("height") as? Int) ?: 960
    private var disposed = false

    init {
        lifecycleRegistry.currentState = Lifecycle.State.RESUMED
        player.setLifecycle(lifecycleRegistry)
        player.setPlayerViewListener(this)

        val mgr = InstaCameraManager.getInstance()
        mgr.setPreviewStatusChangedListener(this)
        // The camera is already connected (Dart mounts this view only once connected). Run the SDK's
        // required pre-preview init before starting the stream — mirrors the demo's
        // CaptureViewModel.initCapture(): fetchCameraOptions → ensure panorama (dual-sensor) →
        // initCameraSupportConfig → setStreamEncode → startPreviewStream. Skipping these leaves the
        // stream open but producing no decodable frames. The process stays bound to the camera Wi-Fi
        // for the whole session (Phase 0 decision D6), which the preview stream requires.
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
            // Match the SDK demo: size the capture params to the laid-out view so the stitched
            // render targets the right dimensions (left at -1 the renderer may not produce output).
            val params = buildCaptureParams().apply {
                width = player.width
                height = player.height
            }
            Log.i(TAG, "onOpened → prepare+play (view ${player.width}x${player.height})")
            player.prepare(params)
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
        Log.i(TAG, "onFirstFrameRender (panorama is rendering on screen)")
    }

    override fun onLoadingFinish() {
        if (disposed) return
        Log.i(TAG, "onLoadingFinish → setPipeline + startExtractMediaFrame ${extractWidth}x$extractHeight")
        val mgr = InstaCameraManager.getInstance()
        mgr.setPipeline(player.pipeline)
        // Extract the stitched ERP result as ARGB MediaFrames. This is the capture-side hand-off
        // point; the optimisation pipeline will later sit between here and the sink.
        player.startExtractMediaFrame(
            extractWidth,
            extractHeight,
            EXTRACT_FPS,
            EXTRACT_QUEUE,
            IMediaFrameCallback { mediaFrame ->
                // The SDK delivers YUV420P. Feed it to the GPU display path (YUV→RGB + forward-mask
                // happen in a GL shader). The CPU pipeline/converter remain available for the
                // transport path (Agora, deferred) but are not run per-frame here.
                mediaFrame?.let { Insta360FrameSink.submitYuv(it) }
            },
        )
    }

    override fun onReleaseCameraPipeline() {
        InstaCameraManager.getInstance().setPipeline(null)
    }

    private fun buildCaptureParams(): CaptureParamsBuilderV2 =
        CaptureParamsBuilderV2().apply {
            renderModel = RenderModel.PLANE_STITCH
            setScreenRatio(2, 1) // equirectangular aspect
        }

    private companion object {
        const val TAG = "Insta360PreviewView"
        const val EXTRACT_FPS = 60
        const val EXTRACT_QUEUE = 32
    }
}
