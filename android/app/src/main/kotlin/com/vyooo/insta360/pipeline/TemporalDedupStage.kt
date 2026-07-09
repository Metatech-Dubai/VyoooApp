package com.vyooo.insta360.pipeline

import kotlin.math.abs

/**
 * Temporal redundancy reduction (Milestone 2).
 *
 * Transmits **≤ 1 frame per [keepEveryN] captured** (N ≥ 2, default 3) via **deterministic
 * scheduling + motion gating**: between the scheduled slots a frame is kept only if the scene has
 * changed enough versus the **last kept (transmitted) frame**, so near-duplicate frames in a static
 * scene are dropped and the encoder simply holds the previous frame (bitrate falls). A generous
 * **heartbeat** ([heartbeatEveryN]) force-keeps a frame even in a fully static scene, so the stream
 * never stalls and a late-joining viewer/encoder always refreshes soon.
 *
 * Dropping is done by returning `null` (the pipeline then forwards nothing for that frame, so
 * `Insta360FrameSink` neither displays nor pushes it). Invariants (Master Plan §3.5):
 *  - **PTS monotonic:** [PipelineFrame.ptsUs] is never modified or reordered; dropping frames keeps
 *    the surviving timestamps strictly increasing.
 *  - **Audio never gated:** audio is Agora's separate mic path and never flows through this pipeline.
 *  - **Conservative over aggressive:** defaults favour stability; motion keeps err toward keeping.
 *
 * Motion metric: mean absolute difference of a coarse [GRID_COLS]×[GRID_ROWS] luma grid vs. the last
 * kept frame, normalised to [0,1] — a few hundred pixel reads per frame, comfortably real-time. An
 * on-device AI layer may override it via [PipelineHints.motion]; when absent the metric is computed.
 *
 * State is touched only on the single SDK extract thread (via `Insta360FrameSink.submit`); [enabled]
 * is `@Volatile` for live A/B toggling from another thread.
 */
class TemporalDedupStage(
    /** Scheduling cap: keep at most 1 frame per N captured (N ≥ 2). Default 3. */
    @JvmField var keepEveryN: Int = 3,
    /** Normalised luma MAD (0..1) above which a frame counts as motion and is kept. */
    @JvmField var motionThreshold: Float = 0.010f,
    /** Force-keep cadence: keep at least 1 frame per this many captured, even in a static scene. */
    @JvmField var heartbeatEveryN: Int = 30,
) : FrameStage {

    override val name: String = "TemporalDedup"

    /**
     * Temporal reduction is **off by default** so the live stream runs at full/original fps — the
     * frame-dropping (≈1 fps in a static scene) made the viewer perceive a freeze. The reduction is
     * still a demonstrable M2 capability: enable it via `Insta360FrameSink.setTemporalEnabled(true)`
     * for A/B / KPI capture. When false, every frame passes through.
     */
    @Volatile
    var enabled: Boolean = false

    // ── Runtime state (extract thread only) ──────────────────────────────────
    // Consecutive frames dropped since the last kept frame. Init "large" so the very first frame is
    // kept (establishes the baseline). Bounded by the heartbeat, so it never overflows.
    private var droppedSinceKept = Int.MAX_VALUE
    private var lastGrid: IntArray? = null
    @Volatile private var lastMotion: Float = 0f

    // ── Cumulative stats (KPI readout) ───────────────────────────────────────
    private var seen = 0L
    private var kept = 0L
    private var motionKeeps = 0L
    private var heartbeatKeeps = 0L
    private var scheduleDrops = 0L
    private var duplicateDrops = 0L

    override fun process(frame: PipelineFrame, hints: PipelineHints): PipelineFrame? {
        if (!enabled) {
            resetRuntimeState()
            return frame
        }

        seen++
        val curGrid = sampleGrid(frame)
        val motion = hints.motion ?: motionFrom(curGrid)
        lastMotion = motion

        val n = keepEveryN.coerceAtLeast(2)
        val minDrops = n - 1
        val heartbeatDrops = heartbeatEveryN.coerceAtLeast(n) - 1

        val keep: Boolean = when {
            droppedSinceKept >= heartbeatDrops -> { heartbeatKeeps++; true } // stability floor
            droppedSinceKept < minDrops -> { scheduleDrops++; false } // ≤ 1 per N cap
            motion >= motionThreshold -> { motionKeeps++; true } // motion gate
            else -> { duplicateDrops++; false } // near-duplicate → drop
        }

        return if (keep) {
            droppedSinceKept = 0
            if (curGrid != null) lastGrid = curGrid
            kept++
            frame
        } else {
            if (droppedSinceKept < Int.MAX_VALUE) droppedSinceKept++
            null
        }
    }

    /** Live KPI snapshot: keep ratio (effective fps fraction), motion-gate rate, drop breakdown. */
    fun stats(): Map<String, Any> = mapOf(
        "temporalEnabled" to enabled,
        "keepEveryN" to keepEveryN,
        "framesSeen" to seen,
        "framesKept" to kept,
        "keepRatio" to if (seen > 0) kept.toDouble() / seen else 1.0,
        "motionKeeps" to motionKeeps,
        "heartbeatKeeps" to heartbeatKeeps,
        "scheduleDrops" to scheduleDrops,
        "duplicateDrops" to duplicateDrops,
        "lastMotion" to lastMotion,
    )

    /** Clear runtime state + cumulative stats (called from `Insta360FrameSink.reset`). */
    fun reset() {
        resetRuntimeState()
        seen = 0; kept = 0; motionKeeps = 0; heartbeatKeeps = 0
        scheduleDrops = 0; duplicateDrops = 0
        lastMotion = 0f
    }

    private fun resetRuntimeState() {
        droppedSinceKept = Int.MAX_VALUE
        lastGrid = null
    }

    /** Normalised (0..1) luma MAD of [cur] vs. the last kept grid; 1 (max, keep) if no baseline. */
    private fun motionFrom(cur: IntArray?): Float {
        if (cur == null) return 1f
        val prev = lastGrid ?: return 1f
        if (prev.size != cur.size) return 1f
        var acc = 0L
        for (i in cur.indices) acc += abs(cur[i] - prev[i])
        return (acc.toDouble() / (cur.size * 255.0)).toFloat().coerceIn(0f, 1f)
    }

    /** Sample a coarse luma grid (centre pixel per cell). Null if the frame buffer is unusable. */
    private fun sampleGrid(frame: PipelineFrame): IntArray? {
        val w = frame.width
        val h = frame.height
        if (w <= 0 || h <= 0) return null
        val px = frame.pixels
        if (px.size < w * h * 4) return null

        val out = IntArray(GRID_COLS * GRID_ROWS)
        var k = 0
        for (ry in 0 until GRID_ROWS) {
            val y = ((ry + 0.5f) * h / GRID_ROWS).toInt().coerceIn(0, h - 1)
            val rowBase = y * w
            for (cx in 0 until GRID_COLS) {
                val x = ((cx + 0.5f) * w / GRID_COLS).toInt().coerceIn(0, w - 1)
                val idx = (rowBase + x) * 4
                val r = px[idx].toInt() and 0xFF
                val g = px[idx + 1].toInt() and 0xFF
                val b = px[idx + 2].toInt() and 0xFF
                // BT.601 luma (integer approx): 0.299R + 0.587G + 0.114B.
                out[k++] = (r * 77 + g * 150 + b * 29) shr 8
            }
        }
        return out
    }

    private companion object {
        const val GRID_COLS = 32
        const val GRID_ROWS = 18
    }
}
