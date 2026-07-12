package com.vyooo.insta360.pipeline

import android.util.Log
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
 * ## Contract with the temporal pacer (M2, time-based variant)
 * [TemporalDedupStage] is a **time-based motion/static pacer**: while *moving* it keeps every frame
 * (full rate); while *static* it keeps one frame per `1/staticFps` s. Its gate is a **binary**
 * compare, `motion >= motionThreshold`. Three consequences shape this layer:
 *
 *  1. **We emit a decision, not a raw metric.** [MutableHints.motion] is set to [SIGNAL_MOVING] /
 *     [SIGNAL_STATIC] (1 / 0), so the gate resolves the same way regardless of how the stage's
 *     threshold is tuned. Raw activity stays observable via [stats] (`aiActivity`). Emitting a raw
 *     top-percentile score instead would be *miscalibrated*: the stage's threshold (0.010) was tuned
 *     against a whole-frame **mean**, while a top-percentile score sits far above it even for sensor
 *     noise — a static scene would read as "moving" and the reduction would silently never engage.
 *  2. **The gate must not flap.** An unstable moving/static decision produces *irregular* frame
 *     spacing — the exact failure that made the earlier frame-count scheduler lag the encoder. So the
 *     decision uses **hysteresis** ([motionEnter] > [motionExit]) plus a **hold** ([motionHoldMs])
 *     after activity subsides.
 *  3. **The measurement must not depend on the gate.** Motion is measured against a **fixed ~[refLagMs]
 *     time-lagged reference**. Making the reference state-dependent (frozen while static, refreshed
 *     while moving) turns the pair into a relaxation oscillator — measured on-device as 32 gate flips
 *     with `effFps` swinging 29↔9. A constant lag also lets a slow pan accumulate across the window,
 *     so it is not silently paced down.
 *
 * ## Signals (contract §3.4 / Patent Fig. 2–3)
 *  - **motion** → [TemporalDedupStage]: hysteretic moving/static decision from a robust,
 *    localized-motion-aware activity score (top-percentile luma difference, EMA-smoothed). Unlike a
 *    whole-frame mean, a small moving region is not averaged away. **Applied live when [enabled].**
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
 * **[enabled] ships `true`** — the layer is *applied live*: it supplies the motion decision the temporal
 * pacer acts on. That is the point of M3; a decision layer that never influences the pipeline would not
 * be a deliverable. Validated on-device (gate stable, full rate in motion, correct static pacing,
 * 0.13–0.55 ms/frame overhead). Set `Insta360FrameSink.setAiEnabled(false)` to fall open to the
 * pipeline's own deterministic metrics — for A/B and KPI capture.
 *
 * State is touched only on the SDK extract thread (via `Insta360FrameSink.submit`); the toggles are
 * `@Volatile` for live control from another thread.
 */
class HeuristicDecisionLayer(private val hints: MutableHints) {

    /**
     * Master enable. **On** → the layer supplies the decision signals the pipeline acts on (M3 applied
     * live). Set to `false` to clear the hints and fall open to the pipeline's own deterministic metrics
     * (the M2 behaviour) — the A/B arm, and the safety path if the layer ever misbehaves.
     */
    @Volatile var enabled: Boolean = true

    /** Apply the computed spatial-reduction recommendation to the hint (default off = mapping only). */
    @Volatile var applyPerceptual: Boolean = false

    /** Apply the computed forward orientation to the hint (default off = mapping only). */
    @Volatile var applyOrientation: Boolean = false

    /** Observe every Nth frame (≥1). 1 = every frame (coarse-grid cost is sub-millisecond). */
    @Volatile var cadence: Int = 1

    // ── Motion decision tuning (top-percentile activity scale, NOT the stage's mean scale) ───
    /** Activity at/above which a static scene is declared **moving**. */
    @Volatile var motionEnter: Float = 0.030f

    /** Activity below which a moving scene may fall back to **static** (hysteresis: < [motionEnter]). */
    @Volatile var motionExit: Float = 0.015f

    /** Stay "moving" this long after activity drops below [motionExit] — damps gate flapping. */
    @Volatile var motionHoldMs: Long = 400

    /**
     * Age of the motion-diff reference. Motion is measured against the frame from ~this long ago — a
     * **constant lag, independent of the gate state** (see [observe]). Long enough that a slow pan
     * accumulates a visible diff; short enough to react promptly.
     */
    @Volatile var refLagMs: Long = 250

    // ── Runtime state (extract thread) ───────────────────────────────────────
    /** Recent grids (ts, grid), trimmed to ~[refLagMs] — the oldest is the fixed-lag motion reference. */
    private val history = ArrayDeque<Pair<Long, IntArray>>()
    private var frameCounter = 0L
    private var activityEma = 0f
    private var detailEma = 0f
    private var thetaEma = 0f
    private var moving = false
    private var belowExitSinceNs = 0L

    // ── Exposed signals + performance metrics ────────────────────────────────
    @Volatile private var lastActivity = 0f
    @Volatile private var lastMoving = false
    @Volatile private var lastPerceptualScale = 1f
    @Volatile private var lastRecommendedScale = 1f
    @Volatile private var lastThetaDeg = 0f
    @Volatile private var lastDetail = 0f
    @Volatile private var decisions = 0L
    @Volatile private var motionSpans = 0L
    @Volatile private var overheadMsEma = 0.0

    /** Observe one frame's luma and update the decision signals. Cheap; safe to call per frame. */
    fun observe(pixels: ByteArray, width: Int, height: Int) {
        if (!enabled) {
            clearHints()
            return
        }
        frameCounter++
        val n = cadence.coerceAtLeast(1)
        // Between observations the previous decision stands (the hint is sticky) — never left stale-null.
        if (frameCounter % n != 0L) return

        val t0 = System.nanoTime()
        val grid = sampleLuma(pixels, width, height) ?: return

        // Activity vs a FIXED ~[refLagMs] time-lagged reference — never a state-dependent one.
        //
        // The reference MUST NOT depend on the moving/static decision. Refreshing it only while moving
        // (and freezing it while static) makes the measurement a function of the state it is supposed
        // to drive, which is a relaxation oscillator: frozen ref → drift accumulates → MOVING → ref now
        // refreshes every frame → consecutive-frame diff collapses to ~noise → STATIC → repeat. Measured
        // on-device: 32 gate flips, effFps swinging 29↔9, `aiMoving=true` while `aiActivity=0.010`.
        //
        // A constant lag fixes it: sustained motion at ~29 fps gives a large diff over 250 ms that does
        // not collapse, a static scene gives only sensor noise, and a slow pan still accumulates across
        // the window (the property the frozen reference was reaching for). Top-percentile (not a
        // whole-frame mean) keeps a small moving region from being averaged away.
        history.addLast(t0 to grid)
        val lagNs = refLagMs * 1_000_000L
        while (history.size > 1 && t0 - history.first().first > lagNs) history.removeFirst()
        val ref = if (history.size > 1) history.first().second else null
        val activity = if (ref == null) 1f else topPercentileDiff(grid, ref)
        activityEma = MOTION_EMA_ALPHA * activity + (1 - MOTION_EMA_ALPHA) * activityEma

        // Hysteretic moving/static decision + hold. A stable gate is essential: a flapping decision
        // gives the encoder irregular frame spacing, which is what lagged the earlier scheduler.
        if (moving) {
            if (activityEma < motionExit) {
                if (belowExitSinceNs == 0L) belowExitSinceNs = t0
                if ((t0 - belowExitSinceNs) / 1_000_000L >= motionHoldMs) {
                    moving = false
                    belowExitSinceNs = 0L
                    // Logged on the flip itself: the ~1/s monitor samples too coarsely to reveal a
                    // short flap, and every flip changes the pacer's rate (full ⇄ staticFps).
                    Log.i(TAG, "gate moving→STATIC activity=${"%.4f".format(activityEma)} exit=$motionExit hold=${motionHoldMs}ms")
                }
            } else {
                belowExitSinceNs = 0L // re-armed by fresh activity
            }
        } else if (activityEma >= motionEnter) {
            moving = true
            belowExitSinceNs = 0L
            motionSpans++
            Log.i(TAG, "gate static→MOVING activity=${"%.4f".format(activityEma)} enter=$motionEnter spans=$motionSpans")
        }

        // Spatial detail: mean neighbour gradient of the grid (texture/complexity estimate).
        val detail = neighbourGradient(grid)
        detailEma = DETAIL_EMA_ALPHA * detail + (1 - DETAIL_EMA_ALPHA) * detailEma

        // Perceptual score in [0,1] (1 = keep full resolution). More detail/activity → keep more.
        val perceptual = (0.5f + 2.0f * detailEma + 0.5f * activityEma).coerceIn(0f, 1f)
        // Recommended reduction factor of the 2K target (bounded — never below RECOMMEND_FLOOR).
        val recommended = (RECOMMEND_FLOOR + (1f - RECOMMEND_FLOOR) * perceptual).coerceIn(RECOMMEND_FLOOR, 1f)

        // Forward orientation: salience-weighted centroid column → θ in degrees, heavily smoothed.
        val theta = salienceCentroidDeg(grid)
        thetaEma = THETA_EMA_ALPHA * theta + (1 - THETA_EMA_ALPHA) * thetaEma

        // Write decision signals (metadata only). `motion` is a DECISION (moving/static), not a raw
        // score — the stage's binary gate then resolves identically whatever its threshold is set to.
        hints.motion = if (moving) SIGNAL_MOVING else SIGNAL_STATIC
        hints.perceptualScale = if (applyPerceptual) perceptual else null
        hints.forwardThetaDeg = if (applyOrientation) thetaEma else null
        // isPanoramic left to the deterministic detector (corroboration hook, not overridden).

        lastActivity = activityEma
        lastMoving = moving
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
        "aiMoving" to lastMoving,          // the decision handed to the temporal pacer
        "aiActivity" to lastActivity,      // raw smoothed activity behind that decision
        "aiMotionSpans" to motionSpans,    // static→moving transitions (gate-stability KPI)
        "aiSpatialDetail" to lastDetail,
        "aiPerceptualScale" to lastPerceptualScale,
        "aiRecommendedScale" to lastRecommendedScale,
        "aiThetaDeg" to lastThetaDeg,
    )

    fun reset() {
        history.clear()
        frameCounter = 0
        activityEma = 0f; detailEma = 0f; thetaEma = 0f
        moving = false; belowExitSinceNs = 0L
        lastActivity = 0f; lastMoving = false
        lastPerceptualScale = 1f; lastRecommendedScale = 1f; lastThetaDeg = 0f; lastDetail = 0f
        decisions = 0; motionSpans = 0; overheadMsEma = 0.0
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
        const val TAG = "HeuristicAI"
        const val GRID_COLS = 32
        const val GRID_ROWS = 18
        const val TOP_FRACTION = 0.15f
        const val MOTION_EMA_ALPHA = 0.4f
        const val DETAIL_EMA_ALPHA = 0.2f
        const val THETA_EMA_ALPHA = 0.05f // heavy smoothing → stable forward direction
        const val RECOMMEND_FLOOR = 0.5f // never recommend below 50% of the 2K target

        /** Decision values written to [MutableHints.motion] — read by the pacer's binary gate. */
        const val SIGNAL_MOVING = 1.0f
        const val SIGNAL_STATIC = 0.0f
    }
}
