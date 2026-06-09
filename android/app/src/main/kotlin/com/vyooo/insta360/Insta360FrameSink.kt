package com.vyooo.insta360

import com.arashivision.graphicpath.insmedia.common.MediaFrame
import com.vyooo.insta360.pipeline.FramePipeline
import com.vyooo.insta360.pipeline.PipelineFrame
import java.nio.ByteBuffer

/**
 * The single insertion point for extracted Insta360 frames. Two paths share it:
 *
 * 1. **GPU display path (live, Milestone 1).** [submitYuv] forwards the raw I420 frame to
 *    [onYuvFrame] → [Insta360GlRenderer], which does YUV→RGB + forward-mask in a GL shader. This is
 *    what the host actually sees; it does no CPU per-pixel work.
 *
 * 2. **CPU pipeline path (reference / transport).** [submit] runs an extracted RGBA frame through the
 *    capture-side optimisation [FramePipeline] (Downscale → PanoramaDetect → ForwardMask →
 *    TemporalDedup placeholder), then forwards via [onFrame] (Dart → Agora `pushVideoFrame`). This is
 *    the deterministic, modular reference implementation of the patent stages and the transport path
 *    for when Agora push is re-enabled; it is currently dormant (the live host display uses path 1).
 *
 * [onStats] reports resolution + fps + count (~1×/sec). Frames arrive on an SDK thread; listeners
 * marshal to the main thread.
 */
object Insta360FrameSink {

    /** (width, height, fps, totalCount) — emitted ~1×/sec. */
    @Volatile var onStats: ((Int, Int, Int, Long) -> Unit)? = null

    /** (rgbaBytes, width, height, ptsUs). Only invoked when [streamingEnabled]. */
    @Volatile var onFrame: ((ByteArray, Int, Int, Long) -> Unit)? = null

    @Volatile var streamingEnabled: Boolean = false

    /** The optimisation pipeline. Defaults to the Milestone-1 chain; null = raw pass-through. */
    @Volatile var pipeline: FramePipeline? = FramePipeline.defaultM1()

    /** Toggle the pipeline off for A/B comparison (e.g. bitrate-reduction validation). */
    @Volatile var pipelineEnabled: Boolean = true

    /**
     * Raw-YUV passthrough for the **GPU display path** ([Insta360GlRenderer]). Invoked synchronously
     * on the SDK extract thread with the I420 [MediaFrame] (valid only for the call). The GL renderer
     * does YUV→RGB + forward-mask on the GPU, so this path skips the CPU pipeline entirely.
     */
    @Volatile var onYuvFrame: ((MediaFrame) -> Unit)? = null

    private var yuvCount: Long = 0
    private var yuvWindowNs: Long = 0
    private var yuvFramesWindow: Int = 0
    @Volatile private var yuvFps: Int = 0

    private var count: Long = 0
    private var windowStartNs: Long = 0
    private var framesThisWindow: Int = 0
    private var lastFps: Int = 0
    private var basePtsNs: Long = 0

    // Reusable working buffer so the pipeline owns the pixels (the SDK plane may be recycled).
    private var work: ByteArray = ByteArray(0)

    @Synchronized
    fun reset() {
        count = 0; windowStartNs = 0; framesThisWindow = 0; lastFps = 0; basePtsNs = 0
    }

    /** Live metrics: GPU display fps/count plus the CPU pipeline snapshot (empty while GPU path runs). */
    fun metrics(): Map<String, Any> {
        val m = HashMap<String, Any>()
        m["displayFps"] = yuvFps
        m["displayFrames"] = yuvCount
        pipeline?.metrics?.snapshot()?.let { m.putAll(it) }
        return m
    }

    /**
     * Submit one raw I420 frame for the GPU display path. Counts fps and forwards to [onYuvFrame].
     * Used instead of [submit] when the GL renderer is active (no CPU YUV→RGB / pipeline work).
     */
    @Synchronized
    fun submitYuv(frame: MediaFrame) {
        yuvCount++
        val now = System.nanoTime()
        if (yuvWindowNs == 0L) yuvWindowNs = now
        yuvFramesWindow++
        if (now - yuvWindowNs >= 1_000_000_000L) {
            yuvFps = yuvFramesWindow
            yuvFramesWindow = 0
            yuvWindowNs = now
        }
        onYuvFrame?.invoke(frame)
    }

    /**
     * Submit one extracted frame. [plane] is the RGBA buffer from the SDK's MediaFrame
     * (`mediaFrame.planes[0]`); it is only read here and may be reused by the SDK afterwards.
     */
    @Synchronized
    fun submit(plane: ByteBuffer?, width: Int, height: Int) {
        if (plane == null || width <= 0 || height <= 0) return
        val needed = width * height * 4
        // Guard on capacity, not remaining(): the SDK hands us the plane with its position at the
        // end (remaining == 0), so a remaining()-based check would drop every frame.
        if (plane.capacity() < needed) return

        val now = System.nanoTime()
        if (basePtsNs == 0L) basePtsNs = now
        val ptsUs = (now - basePtsNs) / 1000

        val frameCb = onFrame
        val needStream = streamingEnabled && frameCb != null
        val p = pipeline

        var outW = width
        var outH = height
        var bytes: ByteArray? = null // materialised RGBA in [work] when needed

        // Copy the plane into our own buffer (read from position 0) so stages may mutate it and the
        // SDK may recycle the plane. Done once and shared by the pipeline / stream paths.
        if ((p != null && pipelineEnabled) || needStream) {
            if (work.size < needed) work = ByteArray(needed)
            val src = plane.duplicate()
            src.clear() // position = 0, limit = capacity
            src.get(work, 0, needed)
        }

        if (p != null && pipelineEnabled) {
            val result = p.process(PipelineFrame(work, width, height, ptsUs))
                ?: return // frame dropped by a stage (e.g. temporal dedup, M2)
            bytes = result.pixels
            outW = result.width
            outH = result.height
        } else if (needStream) {
            bytes = work
        }

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

        // Transmit path (Dart → Agora) — own copy, the consumer may retain it.
        if (needStream && bytes != null) {
            val outBytes = outW * outH * 4
            val copy = ByteArray(outBytes)
            System.arraycopy(bytes, 0, copy, 0, outBytes)
            frameCb?.invoke(copy, outW, outH, ptsUs)
        }
    }
}
