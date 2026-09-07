package com.vyooo.viewer

import android.content.Context
import android.util.Log
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import io.flutter.plugin.platform.PlatformView

/**
 * Flutter [PlatformView] hosting the GL surface for the head-tracked 360 sphere.
 *
 * It embeds a [SurfaceView] and drives a [ViewerSphereRenderer] against its surface. The renderer
 * reads the VITURE head pose natively for low latency; this view only manages the surface lifecycle
 * and forwards the two external inputs it receives from Dart via [ViewerSphereBridge]:
 *   - [submitYuv]  — the next Agora ERP frame (I420) to draw
 *   - [setExternalOrientation] / [clearExternalOrientation] — the touch/gyro fallback
 *
 * Only one sphere view is mounted at a time (the fullscreen viewer), tracked by [active] so the bridge
 * can route frames/orientation to it without a per-view channel — mirrors [com.vyooo.insta360.Insta360PreviewView].
 */
class ViewerSphereView(
    context: Context,
    @Suppress("UNUSED_PARAMETER") creationParams: Map<String, Any?>?,
) : PlatformView, SurfaceHolder.Callback {

    private val surfaceView = SurfaceView(context)
    private var renderer: ViewerSphereRenderer? = null
    private var disposed = false

    init {
        active = this
        surfaceView.holder.addCallback(this)
    }

    override fun getView(): View = surfaceView

    override fun dispose() {
        if (disposed) return
        disposed = true
        if (active === this) active = null
        surfaceView.holder.removeCallback(this)
        renderer?.dispose()
        renderer = null
    }

    // ── SurfaceHolder lifecycle ──────────────────────────────────────────────────────────────────

    override fun surfaceCreated(holder: SurfaceHolder) {
        if (disposed) return
        val w = surfaceView.width.coerceAtLeast(1)
        val h = surfaceView.height.coerceAtLeast(1)
        renderer = ViewerSphereRenderer(holder.surface).also { it.start(w, h) }
        Log.i(TAG, "surfaceCreated → renderer started (${w}x$h)")
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        if (disposed) return
        renderer?.resize(width, height)
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        renderer?.dispose()
        renderer = null
    }

    // ── Inputs forwarded from the bridge ─────────────────────────────────────────────────────────

    private fun submitYuvInternal(
        y: ByteArray, u: ByteArray, v: ByteArray,
        width: Int, height: Int, yStride: Int, uStride: Int, vStride: Int,
    ) {
        renderer?.submitYuv(y, u, v, width, height, yStride, uStride, vStride)
    }

    private fun setExternalOrientationInternal(yaw: Float, pitch: Float) {
        renderer?.setExternalOrientation(yaw, pitch)
    }

    private fun clearExternalOrientationInternal() {
        renderer?.clearExternalOrientation()
    }

    companion object {
        private const val TAG = "ViewerSphereView"

        /** The currently-mounted sphere view (only one at a time). */
        @Volatile private var active: ViewerSphereView? = null

        /** Push one I420 ERP frame to the live sphere. No-op when no sphere is mounted. */
        fun submitYuv(
            y: ByteArray, u: ByteArray, v: ByteArray,
            width: Int, height: Int, yStride: Int, uStride: Int, vStride: Int,
        ) = active?.submitYuvInternal(y, u, v, width, height, yStride, uStride, vStride)

        /** Enable the touch/gyro fallback (degrees). */
        fun setExternalOrientation(yaw: Float, pitch: Float) =
            active?.setExternalOrientationInternal(yaw, pitch)

        /** Hand the camera back to the VITURE head pose. */
        fun clearExternalOrientation() = active?.clearExternalOrientationInternal()
    }
}
