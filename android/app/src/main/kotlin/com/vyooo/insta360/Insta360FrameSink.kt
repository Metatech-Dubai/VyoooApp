package com.vyooo.insta360

import android.util.Log
import com.arashivision.graphicpath.insmedia.common.MediaFrame
import com.vyooo.insta360.pipeline.DownscaleStage
import com.vyooo.insta360.pipeline.ForwardMaskStage
import com.vyooo.insta360.pipeline.FramePipeline
import com.vyooo.insta360.pipeline.HeuristicDecisionLayer
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

    /** AI-fed decision hints; deterministic (all null) until the decision layer writes them. */
    val hints = MutableHints()

    /** M3 bounded heuristic decision layer — writes decision signals into [hints] (metadata only). */
    val decisionLayer = HeuristicDecisionLayer(hints)

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

    /** Live AI decision-layer toggle (off = deterministic fall-open) — for A/B / KPI capture. */
    fun setAiEnabled(enabled: Boolean) {
        decisionLayer.enabled = enabled
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
    private var lastLogSpans: Long = 0

    private const val TAG = "Insta360FrameSink"

    // Cap the transmit copy rate. Each transmitted frame allocates a fresh ~7 MB copy (+ another
    // ~7 MB in the platform-channel codec). The effective transmit rate is bottlenecked by the
    // native→Dart platform channel (~11 fps for these 7 MB frames), well below this cap, so 24 fps
    // is just a safety ceiling — raising it does not raise fps (that needs a native push path).
    private const val TRANSMIT_MIN_INTERVAL_NS = 1_000_000_000L / 24

    @Synchronized
    fun reset() {
        count = 0; windowStartNs = 0; framesThisWindow = 0; lastFps = 0; basePtsNs = 0
        lastTransmitNs = 0
        lastTemporalLogNs = 0; lastLogSeen = 0; lastLogKept = 0; lastLogSpans = 0
        pipeline.metrics.reset()
        temporalDedup.reset()
        decisionLayer.reset()
    }

    /** Live metrics: output fps + the pipeline snapshot (per-stage latency, spatial + temporal). */
    fun metrics(): Map<String, Any> {
        val m = HashMap<String, Any>()
        m["fps"] = lastFps
        m["framesOut"] = count
        m.putAll(pipeline.metrics.snapshot())
        m.putAll(temporalDedup.stats())
        m.putAll(decisionLayer.stats())
        return m
    }

    /**
     * Throttled (~1/s) logcat monitor of the temporal stage + the M3 decision layer — the on-device
     * stability readout. `capFps` (frames arriving from the camera) staying steady = real-time
     * sustained / no backlog; `effFps` (frames kept) is the temporally-reduced output rate — in a
     * static scene it should settle at `staticFps`, in motion it tracks `capFps`.
     *
     * AI side: `aiMoving` is the decision handed to the pacer (so `lastMotion` reads 1.000/0.000 when
     * the layer is on — that is the decision, not a score); `aiActivity` is the raw score behind it
     * (use it to tune `motionEnter`/`motionExit`); `aiSpans/s` is the **gate-stability** KPI — it must
     * stay near 0 in a steady scene, since a flapping gate gives the encoder irregular frame spacing.
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
        val ai = decisionLayer.stats()
        // Gate-stability KPI: static→moving transitions per second. A steady scene should sit near 0;
        // a climbing rate means the motion gate is flapping → irregular frame spacing into the encoder.
        val spans = ai["aiMotionSpans"] as Long
        val spansPerSec = (spans - lastLogSpans) / secs
        lastLogSpans = spans
        Log.i(
            TAG,
            "temporal enabled=${s["temporalEnabled"]} " +
                "capFps=${"%.1f".format(capFps)} effFps=${"%.1f".format(effFps)} " +
                "keepRatio=${"%.2f".format(s["keepRatio"] as Double)} " +
                "staticFps=${s["staticFps"]} " +
                "kept=$kept/$seen motionKeep=${s["motionKeeps"]} staticKeep=${s["staticKeeps"]} " +
                "staticDrop=${s["staticDrops"]} " +
                "lastMotion=${"%.3f".format(s["lastMotion"] as Float)} | " +
                "ai=${ai["aiEnabled"]} aiMoving=${ai["aiMoving"]} " +
                "aiActivity=${"%.3f".format(ai["aiActivity"] as Float)} " +
                "aiDetail=${"%.3f".format(ai["aiSpatialDetail"] as Float)} " +
                "aiRecScale=${"%.2f".format(ai["aiRecommendedScale"] as Float)} " +
                "aiTheta=${"%.1f".format(ai["aiThetaDeg"] as Float)} " +
                "aiSpans=$spans (${"%.1f".format(spansPerSec)}/s) " +
                "aiDecisions=${ai["aiDecisions"]} " +
                "aiMs=${"%.2f".format(ai["aiOverheadMs"] as Double)}",
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

        // M3: the heuristic decision layer observes this frame and writes decision signals (metadata)
        // into `hints` BEFORE the pipeline runs, so the stages read fresh AI-assisted hints this frame.
        decisionLayer.observe(rgba, w, h)

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
