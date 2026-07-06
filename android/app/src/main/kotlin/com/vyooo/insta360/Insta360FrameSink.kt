package com.vyooo.insta360

import android.util.Log
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
 * One deterministic processing path:
 *
 * ```
 * MediaFrame (YUV420P) → YUV→RGB → FramePipeline[ Downscale → PanoramaDetect → ForwardMask →
 *                                                  TemporalDedup ] → processed RGBA
 *      ├─► onProcessedFrame  (host display — the Flutter texture; always)
 *      └─► onFrame           (encoder / transport — Agora; when streamingEnabled)
 * ```
 *
 * A stage may drop a frame (pipeline returns null) — nothing is forwarded for that frame, so the
 * display and the transmitted stream stay in lock-step. [Insta360GlRenderer] only uploads the
 * processed RGBA to the texture; the pipeline is the single source of truth for the optimisation.
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
    private val temporalDedup = TemporalDedupStage()

    /** AI-fed decision hints; deterministic (all null) until an AI layer writes them. */
    val hints = MutableHints()

    val pipeline = FramePipeline(
        listOf(DownscaleStage(), PanoramaDetectStage(), forwardMask, temporalDedup),
        hints,
    )

    /** Live masked/unmasked toggle (forward-only suppression on/off). */
    fun setMaskEnabled(enabled: Boolean) {
        forwardMask.enabled = enabled
    }

    /** Live temporal-reduction toggle (1-in-N + motion gating on/off) — for A/B / KPI capture. */
    fun setTemporalEnabled(enabled: Boolean) {
        temporalDedup.enabled = enabled
    }

    private var count: Long = 0
    private var windowStartNs: Long = 0
    private var framesThisWindow: Int = 0
    private var lastFps: Int = 0
    private var basePtsNs: Long = 0
    private var lastTransmitNs: Long = 0
    private var lastTemporalLogNs: Long = 0
    private var lastLogSeen: Long = 0
    private var lastLogKept: Long = 0

    private const val TAG = "Insta360FrameSink"

    // Cap the transmit copy rate. The pipeline runs at the extract rate (~60 fps) to keep the host
    // display smooth, but each transmitted frame allocates a fresh ~7 MB copy (+ another ~7 MB in the
    // platform-channel codec), so forwarding all 60 fps thrashes the heap. The Agora encoder runs at
    // 15 fps; 24 fps here gives it full frames with headroom while cutting allocation churn ~2.5×.
    private const val TRANSMIT_MIN_INTERVAL_NS = 1_000_000_000L / 24

    @Synchronized
    fun reset() {
        count = 0; windowStartNs = 0; framesThisWindow = 0; lastFps = 0; basePtsNs = 0
        lastTransmitNs = 0
        lastTemporalLogNs = 0; lastLogSeen = 0; lastLogKept = 0
        pipeline.metrics.reset()
        temporalDedup.reset()
    }

    /** Live metrics: output fps + the pipeline snapshot (per-stage latency, spatial + temporal). */
    fun metrics(): Map<String, Any> {
        val m = HashMap<String, Any>()
        m["fps"] = lastFps
        m["framesOut"] = count
        m.putAll(pipeline.metrics.snapshot())
        m.putAll(temporalDedup.stats())
        return m
    }

    /**
     * Throttled (~1/s) logcat monitor of the temporal stage — the on-device stability readout.
     * `capFps` (frames arriving from the camera) staying steady = real-time sustained / no backlog;
     * `effFps` (frames kept) is the temporally-reduced output rate; the two together show frame
     * pacing and that drops never run away (effFps holds at the heartbeat floor in a static scene).
     */
    private fun maybeLogTemporal(nowNs: Long) {
        val dt = nowNs - lastTemporalLogNs
        if (dt < 1_000_000_000L) return
        val s = temporalDedup.stats()
        val seen = s["framesSeen"] as Long
        val kept = s["framesKept"] as Long
        val secs = dt / 1_000_000_000.0
        val capFps = (seen - lastLogSeen) / secs
        val effFps = (kept - lastLogKept) / secs
        lastTemporalLogNs = nowNs
        lastLogSeen = seen
        lastLogKept = kept
        Log.i(
            TAG,
            "temporal enabled=${s["temporalEnabled"]} " +
                "capFps=${"%.1f".format(capFps)} effFps=${"%.1f".format(effFps)} " +
                "keepRatio=${"%.2f".format(s["keepRatio"] as Double)} " +
                "kept=$kept/$seen motion=${s["motionKeeps"]} heartbeat=${s["heartbeatKeeps"]} " +
                "schedDrop=${s["scheduleDrops"]} dupDrop=${s["duplicateDrops"]} " +
                "lastMotion=${"%.3f".format(s["lastMotion"] as Float)}",
        )
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
        maybeLogTemporal(now) // ~1/s monitor of the temporal stage — logs even on dropped frames
        result ?: return // dropped by a stage (e.g. temporal dedup)
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

        // Encoder / transport — own copy so the consumer may retain it. Rate-capped (see
        // TRANSMIT_MIN_INTERVAL_NS): the 60 fps pipeline feeds the display, but transmitting every
        // frame allocated a fresh ~7 MB copy 60×/s and OOM-crashed the app under load.
        if (streamingEnabled && now - lastTransmitNs >= TRANSMIT_MIN_INTERVAL_NS) {
            val cb = onFrame
            if (cb != null) {
                lastTransmitNs = now
                val outBytes = outW * outH * 4
                val copy = ByteArray(outBytes)
                System.arraycopy(result.pixels, 0, copy, 0, outBytes)
                cb.invoke(copy, outW, outH, ptsUs)
            }
        }
    }
}
