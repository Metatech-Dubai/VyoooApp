package com.vyooo.insta360.pipeline

import kotlin.math.abs

/**
 * Milestone 3 — bounded, on-device, **heuristic** AI-assisted decision layer (the "AI Assist" /
 * "On-device AI" module in the patent diagrams).
 *
 * It observes low-cost scene statistics from a coarse luma grid (the "preview / luma" input) and
 * writes **decision signals only** into the shared [MutableHints] that the deterministic pipeline
 * already consumes. It never sees or modifies pixel content beyond reading a downscaled luma sample,
 * and the pipeline runs unchanged when this layer is disabled (deterministic fall-open).
 *
 * Signals (contract §3.4 / Patent Fig. 2–3):
 *  - **motion** → [TemporalDedupStage]: robust scene activity (top-percentile luma difference,
 *    EMA-smoothed) — sensitive to *localized* motion, unlike a whole-frame mean. **Applied live.**
 *  - **perceptualScale** → [DownscaleStage]: scene-complexity score → a recommended reduction.
 *    Computed + exposed; applied to the hint only when [applyPerceptual] (default off, for a stable
 *    live resolution — demonstration-grade per the contract).
 *  - **forwardThetaDeg** → [ForwardMaskStage]: salience-centroid orientation, heavily smoothed.
 *    Computed + exposed; applied only when [applyOrientation] (default off — the mask stays put; the
 *    field size F is never changed, per the patent).
 *
 * Constraints honoured: metadata-only, no pixel modification, no training/cloud, deterministic
 * fall-open, bounded (a few hundred luma reads per observation).
 *
 * State is touched only on the SDK extract thread (via `Insta360FrameSink.submit`); the toggle/flags
 * are `@Volatile` for live control from another thread.
 */
class HeuristicDecisionLayer(private val hints: MutableHints) {

    /** Master enable. When false the layer clears its hints → the pipeline falls open (M2 behaviour). */
    @Volatile var enabled: Boolean = true

    /** Apply the computed spatial-reduction recommendation to the hint (default off = mapping only). */
    @Volatile var applyPerceptual: Boolean = false

    /** Apply the computed forward orientation to the hint (default off = mapping only). */
    @Volatile var applyOrientation: Boolean = false

    /** Observe every Nth frame (≥1). 1 = every frame (coarse-grid cost is sub-millisecond). */
    @Volatile var cadence: Int = 1

    // ── Runtime state (extract thread) ───────────────────────────────────────
    private var prevGrid: IntArray? = null
    private var frameCounter = 0L
    private var motionEma = 0f
    private var detailEma = 0f
    private var thetaEma = 0f

    // ── Exposed signals + performance metrics ────────────────────────────────
    @Volatile private var lastMotion = 0f
    @Volatile private var lastPerceptualScale = 1f
    @Volatile private var lastRecommendedScale = 1f
    @Volatile private var lastThetaDeg = 0f
    @Volatile private var lastDetail = 0f
    @Volatile private var decisions = 0L
    @Volatile private var overheadMsEma = 0.0

    /** Observe one frame's luma and update the decision signals. Cheap; safe to call per frame. */
    fun observe(pixels: ByteArray, width: Int, height: Int) {
        if (!enabled) {
            clearHints()
            return
        }
        frameCounter++
        val n = cadence.coerceAtLeast(1)
        if (frameCounter % n != 0L) return

        val t0 = System.nanoTime()
        val grid = sampleLuma(pixels, width, height) ?: return

        // Motion: top-percentile mean of per-cell luma differences vs the previous observation. Using
        // the top fraction (not the whole-frame mean) keeps a small moving region from being averaged
        // away, so localized motion is detected steadily. EMA-smoothed to avoid per-frame flicker.
        val rawMotion = prevGrid?.let { topPercentileDiff(grid, it) } ?: 1f
        motionEma = MOTION_EMA_ALPHA * rawMotion + (1 - MOTION_EMA_ALPHA) * motionEma

        // Spatial detail: mean neighbour gradient of the grid (texture/complexity estimate).
        val detail = neighbourGradient(grid)
        detailEma = DETAIL_EMA_ALPHA * detail + (1 - DETAIL_EMA_ALPHA) * detailEma

        // Perceptual score in [0,1] (1 = keep full resolution). More detail/activity → keep more.
        val perceptual = (0.5f + 2.0f * detailEma + 0.5f * motionEma).coerceIn(0f, 1f)
        // Recommended reduction factor of the 2K target (bounded — never below RECOMMEND_FLOOR).
        val recommended = (RECOMMEND_FLOOR + (1f - RECOMMEND_FLOOR) * perceptual).coerceIn(RECOMMEND_FLOOR, 1f)

        // Forward orientation: salience-weighted centroid column → θ in degrees, heavily smoothed.
        val theta = salienceCentroidDeg(grid)
        thetaEma = THETA_EMA_ALPHA * theta + (1 - THETA_EMA_ALPHA) * thetaEma

        // Write decision signals (metadata only).
        hints.motion = motionEma
        hints.perceptualScale = if (applyPerceptual) perceptual else null
        hints.forwardThetaDeg = if (applyOrientation) thetaEma else null
        // isPanoramic left to the deterministic detector (corroboration hook, not overridden).

        prevGrid = grid
        lastMotion = motionEma
        lastPerceptualScale = perceptual
        lastRecommendedScale = recommended
        lastThetaDeg = thetaEma
        lastDetail = detailEma
        decisions++
        val ms = (System.nanoTime() - t0) / 1_000_000.0
        overheadMsEma = if (decisions == 1L) ms else 0.1 * ms + 0.9 * overheadMsEma
    }

    /** Performance-observation + influence-mapping metrics (M3 deliverable #4). */
    fun stats(): Map<String, Any> = mapOf(
        "aiEnabled" to enabled,
        "aiApplyPerceptual" to applyPerceptual,
        "aiApplyOrientation" to applyOrientation,
        "aiDecisions" to decisions,
        "aiOverheadMs" to overheadMsEma,
        "aiMotion" to lastMotion,
        "aiSpatialDetail" to lastDetail,
        "aiPerceptualScale" to lastPerceptualScale,
        "aiRecommendedScale" to lastRecommendedScale,
        "aiThetaDeg" to lastThetaDeg,
    )

    fun reset() {
        prevGrid = null
        frameCounter = 0
        motionEma = 0f; detailEma = 0f; thetaEma = 0f
        lastMotion = 0f; lastPerceptualScale = 1f; lastRecommendedScale = 1f; lastThetaDeg = 0f; lastDetail = 0f
        decisions = 0; overheadMsEma = 0.0
        clearHints()
    }

    private fun clearHints() {
        hints.motion = null
        hints.perceptualScale = null
        hints.forwardThetaDeg = null
    }

    // ── Heuristics ───────────────────────────────────────────────────────────

    /** Mean of the top [TOP_FRACTION] cell differences, normalised to [0,1] — localized-motion aware. */
    private fun topPercentileDiff(cur: IntArray, prev: IntArray): Float {
        if (cur.size != prev.size || cur.isEmpty()) return 1f
        val diffs = IntArray(cur.size) { abs(cur[it] - prev[it]) }
        diffs.sort() // ascending
        val k = (cur.size * TOP_FRACTION).toInt().coerceAtLeast(1)
        var acc = 0L
        for (i in cur.size - k until cur.size) acc += diffs[i]
        return (acc.toDouble() / (k * 255.0)).toFloat().coerceIn(0f, 1f)
    }

    /** Mean absolute right/below neighbour gradient of the grid, normalised to [0,1]. */
    private fun neighbourGradient(grid: IntArray): Float {
        var acc = 0L
        var count = 0
        for (r in 0 until GRID_ROWS) {
            for (c in 0 until GRID_COLS) {
                val v = grid[r * GRID_COLS + c]
                if (c + 1 < GRID_COLS) { acc += abs(v - grid[r * GRID_COLS + c + 1]); count++ }
                if (r + 1 < GRID_ROWS) { acc += abs(v - grid[(r + 1) * GRID_COLS + c]); count++ }
            }
        }
        if (count == 0) return 0f
        return (acc.toDouble() / (count * 255.0)).toFloat().coerceIn(0f, 1f)
    }

    /** Salience-weighted centroid column → θ in degrees ([-180,180], 0 = ERP centre / forward). */
    private fun salienceCentroidDeg(grid: IntArray): Float {
        var wsum = 0.0
        var vsum = 0.0
        for (c in 0 until GRID_COLS) {
            var colSal = 0L
            for (r in 0 until GRID_ROWS) colSal += grid[r * GRID_COLS + c]
            wsum += c.toDouble() * colSal
            vsum += colSal.toDouble()
        }
        if (vsum <= 0.0) return 0f
        val centroidCol = wsum / vsum
        return (((centroidCol / GRID_COLS) - 0.5) * 360.0).toFloat()
    }

    /** Coarse luma grid (centre pixel per cell). Null if the frame buffer is unusable. */
    private fun sampleLuma(px: ByteArray, w: Int, h: Int): IntArray? {
        if (w <= 0 || h <= 0 || px.size < w * h * 4) return null
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
                out[k++] = (r * 77 + g * 150 + b * 29) shr 8 // BT.601 luma
            }
        }
        return out
    }

    private companion object {
        const val GRID_COLS = 32
        const val GRID_ROWS = 18
        const val TOP_FRACTION = 0.15f
        const val MOTION_EMA_ALPHA = 0.4f
        const val DETAIL_EMA_ALPHA = 0.2f
        const val THETA_EMA_ALPHA = 0.05f // heavy smoothing → stable forward direction
        const val RECOMMEND_FLOOR = 0.5f // never recommend below 50% of the 2K target
    }
}
