package com.vyooo.insta360

import com.arashivision.graphicpath.insmedia.common.MediaFrame
import com.vyooo.insta360.pipeline.DownscaleStage
import com.vyooo.insta360.pipeline.ForwardMaskStage
import com.vyooo.insta360.pipeline.FramePipeline
import com.vyooo.insta360.pipeline.MutableHints
import com.vyooo.insta360.pipeline.PanoramaDetectStage
import com.vyooo.insta360.pipeline.PipelineFrame
import com.vyooo.insta360.pipeline.TemporalDedupStage

/**
 * The single insertion point **and** processing hub for extracted Insta360 frames.
 *
 * One deterministic, patent-aligned path:
 *
 * ```
 * MediaFrame (YUV420P) → YUV→RGB → FramePipeline[ Downscale → PanoramaDetect → ForwardMask →
 *                                                  TemporalDedup ] → processed RGBA
 *      ├─► onProcessedFrame  (host display — the Flutter texture; always)
 *      └─► onFrame           (encoder / transport — Agora; when streamingEnabled)
 * ```
 *
 * A stage may drop a frame (pipeline returns null) — nothing is forwarded for that frame, so the
 * display and the transmitted stream stay in lock-step ("what you see is what's transmitted"). The
 * GPU [Insta360GlRenderer] is now only a texture **uploader** of the processed RGBA — the pipeline is
 * the single source of truth for the optimisation (downscale / mask / temporal / AI).
 *
 * Frames arrive on the SDK extract thread; listeners marshal to the main thread as needed.
 */
object Insta360FrameSink {

    /** Processed RGBA for the host display. (rgba, w, h, ptsUs). The buffer is reused — read it now. */
    @Volatile var onProcessedFrame: ((ByteArray, Int, Int, Long) -> Unit)? = null

    /** Processed RGBA for the encoder/transport. Only when [streamingEnabled]; receives its own copy. */
    @Volatile var onFrame: ((ByteArray, Int, Int, Long) -> Unit)? = null

    /** (width, height, fps, totalCount) — emitted ~1×/sec. */
    @Volatile var onStats: ((Int, Int, Int, Long) -> Unit)? = null

    @Volatile var streamingEnabled: Boolean = false

    // ── The capture-side optimisation pipeline (single source of truth) ──────────
    private val forwardMask = ForwardMaskStage()

    /** AI-fed decision hints (Milestone 3); deterministic (all null) until the AI layer writes them. */
    val hints = MutableHints()

    val pipeline = FramePipeline(
        listOf(DownscaleStage(), PanoramaDetectStage(), forwardMask, TemporalDedupStage()),
        hints,
    )

    /** Live masked/unmasked toggle (forward-only suppression on/off). */
    fun setMaskEnabled(enabled: Boolean) {
        forwardMask.enabled = enabled
    }

    private var count: Long = 0
    private var windowStartNs: Long = 0
    private var framesThisWindow: Int = 0
    private var lastFps: Int = 0
    private var basePtsNs: Long = 0

    @Synchronized
    fun reset() {
        count = 0; windowStartNs = 0; framesThisWindow = 0; lastFps = 0; basePtsNs = 0
        pipeline.metrics.reset()
    }

    /** Live metrics: output fps + the pipeline snapshot (per-stage latency, spatial reduction, drops). */
    fun metrics(): Map<String, Any> {
        val m = HashMap<String, Any>()
        m["fps"] = lastFps
        m["framesOut"] = count
        m.putAll(pipeline.metrics.snapshot())
        return m
    }

    /**
     * Submit one extracted I420 [frame]: convert → run the pipeline → fan out to display + encoder.
     * Returns early (nothing forwarded) if conversion fails or a stage drops the frame.
     */
    @Synchronized
    fun submit(frame: MediaFrame) {
        val w = frame.width
        val h = frame.height
        if (w <= 0 || h <= 0) return

        val rgba = Insta360YuvConverter.toRgba(frame) ?: return

        val now = System.nanoTime()
        if (basePtsNs == 0L) basePtsNs = now
        val ptsUs = (now - basePtsNs) / 1000

        val result = pipeline.process(PipelineFrame(rgba, w, h, ptsUs))
            ?: return // dropped by a stage (e.g. temporal dedup)
        val outW = result.width
        val outH = result.height

        count++
        // fps over a 1-second sliding window
        if (windowStartNs == 0L) windowStartNs = now
        framesThisWindow++
        if (now - windowStartNs >= 1_000_000_000L) {
            lastFps = framesThisWindow
            framesThisWindow = 0
            windowStartNs = now
            onStats?.invoke(outW, outH, lastFps, count)
        }

        // Host display — reads the (reused) buffer immediately.
        onProcessedFrame?.invoke(result.pixels, outW, outH, ptsUs)

        // Encoder / transport — own copy so the consumer may retain it.
        if (streamingEnabled) {
            val cb = onFrame
            if (cb != null) {
                val outBytes = outW * outH * 4
                val copy = ByteArray(outBytes)
                System.arraycopy(result.pixels, 0, copy, 0, outBytes)
                cb.invoke(copy, outW, outH, ptsUs)
            }
        }
    }
}
