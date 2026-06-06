package com.vyooo.insta360

import java.nio.ByteBuffer

/**
 * The single insertion point for extracted Insta360 frames.
 *
 * Phase 0 keeps this a pass-through fan-out:
 *  - always computes lightweight stats (resolution + fps + count),
 *  - optionally forwards raw RGBA bytes (the de-risk spike: Dart → Agora `pushVideoFrame`).
 *
 * **This is where the patented optimisation pipeline (Downscale → PanoramaDetect → ForwardMask →
 * TemporalDedup) plugs in later** — it will transform/drop frames *before* [onFrame] forwards them.
 * Keeping the contract here means the pipeline can be added without touching capture or transport.
 *
 * Frames arrive on an SDK thread; listeners are responsible for marshalling to the main thread.
 */
object Insta360FrameSink {

    /** (width, height, fps, totalCount) — emitted ~1×/sec. */
    @Volatile var onStats: ((Int, Int, Int, Long) -> Unit)? = null

    /** (rgbaBytes, width, height, ptsUs). Only invoked when [streamingEnabled]. */
    @Volatile var onFrame: ((ByteArray, Int, Int, Long) -> Unit)? = null

    @Volatile var streamingEnabled: Boolean = false

    private var count: Long = 0
    private var windowStartNs: Long = 0
    private var framesThisWindow: Int = 0
    private var lastFps: Int = 0
    private var basePtsNs: Long = 0

    @Synchronized
    fun reset() {
        count = 0; windowStartNs = 0; framesThisWindow = 0; lastFps = 0; basePtsNs = 0
    }

    /**
     * Submit one extracted frame. [plane] is the ARGB/RGBA buffer from the SDK's MediaFrame
     * (`mediaFrame.planes[0]`); it is only read here and may be reused by the SDK afterwards.
     */
    @Synchronized
    fun submit(plane: ByteBuffer?, width: Int, height: Int) {
        if (plane == null || width <= 0 || height <= 0) return
        val now = System.nanoTime()
        if (basePtsNs == 0L) basePtsNs = now
        count++

        // fps over a 1-second sliding window
        if (windowStartNs == 0L) windowStartNs = now
        framesThisWindow++
        if (now - windowStartNs >= 1_000_000_000L) {
            lastFps = framesThisWindow
            framesThisWindow = 0
            windowStartNs = now
            onStats?.invoke(width, height, lastFps, count)
        }

        val frameCb = onFrame
        if (streamingEnabled && frameCb != null) {
            val needed = width * height * 4
            if (plane.remaining() >= needed) {
                val bytes = ByteArray(needed)
                val dup = plane.duplicate()
                dup.get(bytes, 0, needed)
                val ptsUs = (now - basePtsNs) / 1000
                frameCb.invoke(bytes, width, height, ptsUs)
            }
        }
    }
}
