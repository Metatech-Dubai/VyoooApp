package com.vyooo.insta360.pipeline

import kotlin.math.abs

/**
 * Temporal redundancy reduction — **motion/static time-paced** variant.
 *
 * Goal: keep the live stream at **full/original fps while there is motion**, and drop to an
 * **evenly-spaced [staticFps]** (default 10) while the scene is static — so a static scene reduces
 * bitrate without freezing (10 fps ≫ the ~1 fps a frozen scene showed) and without the *irregular*
 * timing that a frame-count "1-in-N" drop produced (which lagged when combined with the SDK's bursty
 * frame delivery). Pacing is **time-based** ([PipelineFrame.ptsUs]) so kept static frames are evenly
 * spaced ⇒ smooth for the viewer/encoder.
 *
 * Decision per frame:
 *  - **motion** (luma change ≥ [motionThreshold]) → **keep** (full rate).
 *  - **static** → keep only if ≥ `1/[staticFps]` s since the last kept frame; else **drop** (`null`).
 *
 * Invariants: PTS never modified/reordered (dropping keeps timestamps monotonic); audio is Agora's
 * separate path and never gated. Motion may be supplied by the AI layer via [PipelineHints.motion];
 * otherwise it is computed from a coarse luma grid. State is touched only on the SDK extract thread;
 * [enabled] is `@Volatile` for live A/B toggling.
 *
 * (This is the product-tuned behaviour; the patent's strict frame-count "≤1 per N" scheduler is
 * preserved in history on the M2 branch.)
 */
class TemporalDedupStage(
    /** Normalised luma MAD (0..1) at/above which a frame counts as motion → kept at full rate. */
    @JvmField var motionThreshold: Float = 0.010f,
    /** Frames/sec transmitted while static — evenly time-paced so the output stays smooth. */
    @JvmField var staticFps: Int = 10,
) : FrameStage {

    override val name: String = "TemporalDedup"

    /** Live A/B toggle. When false every frame passes through (no reduction). */
    @Volatile
    var enabled: Boolean = true

    // ── Runtime state (extract thread only) ──────────────────────────────────
    private var lastKeptPtsUs = Long.MIN_VALUE
    private var lastGrid: IntArray? = null
    @Volatile private var lastMotion: Float = 0f

    // ── Cumulative stats (KPI readout) ───────────────────────────────────────
    private var seen = 0L
    private var kept = 0L
    private var motionKeeps = 0L
    private var staticKeeps = 0L
    private var staticDrops = 0L

    override fun process(frame: PipelineFrame, hints: PipelineHints): PipelineFrame? {
        if (!enabled) {
            resetRuntimeState()
            return frame
        }

        seen++
        val curGrid = sampleGrid(frame)
        val motion = hints.motion ?: motionFrom(curGrid)
        lastMotion = motion

        val moving = motion >= motionThreshold
        val minGapUs = 1_000_000L / staticFps.coerceAtLeast(1)
        val elapsedUs =
            if (lastKeptPtsUs == Long.MIN_VALUE) Long.MAX_VALUE else frame.ptsUs - lastKeptPtsUs
        // Keep every motion frame (full rate); in a static scene keep one frame per staticFps window.
        val keep = moving || elapsedUs >= minGapUs

        return if (keep) {
            lastKeptPtsUs = frame.ptsUs
            if (curGrid != null) lastGrid = curGrid
            kept++
            if (moving) motionKeeps++ else staticKeeps++
            frame
        } else {
            staticDrops++
            null
        }
    }

    /** Live KPI snapshot: keep ratio, motion vs. static-paced keeps, static drops. */
    fun stats(): Map<String, Any> = mapOf(
        "temporalEnabled" to enabled,
        "staticFps" to staticFps,
        "framesSeen" to seen,
        "framesKept" to kept,
        "keepRatio" to if (seen > 0) kept.toDouble() / seen else 1.0,
        "motionKeeps" to motionKeeps,
        "staticKeeps" to staticKeeps,
        "staticDrops" to staticDrops,
        "lastMotion" to lastMotion,
    )

    /** Clear runtime state + cumulative stats (called from `Insta360FrameSink.reset`). */
    fun reset() {
        resetRuntimeState()
        seen = 0; kept = 0; motionKeeps = 0; staticKeeps = 0; staticDrops = 0
        lastMotion = 0f
    }

    private fun resetRuntimeState() {
        lastKeptPtsUs = Long.MIN_VALUE
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
