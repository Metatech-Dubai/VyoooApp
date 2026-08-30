package com.vyooo.insta360.pipeline

/**
 * Capture-side spatial reduction (Patent §2 — resolution normalisation), with the **AI-assisted
 * decision mapping** of Milestone 3.
 *
 * Two reductions happen on the way here, and this stage owns the second:
 *  1. The Insta360 SDK's `startExtractMediaFrame(W_t, H_t, …)` renders the stitched ERP to the extract
 *     target on its GPU — the source→extract reduction, reported via [reductionRatio].
 *  2. **This stage** resamples the extracted frame to the *active tier* ([activeWidth] × [activeHeight]),
 *     a deterministic area-average that preserves the 2:1 ERP aspect.
 *
 * **AI influence (M3).** The decision layer emits [PipelineHints.perceptualScale] — a bounded
 * *metadata signal* in `[0,1]`, never a resolution. This stage maps that signal to a tier through
 * [tierFor], a pure deterministic function. The AI therefore *governs* the spatial reduction without
 * ever selecting a resolution or touching a pixel, satisfying the patent's "decision signals only"
 * constraint. With the hint absent (AI off) the stage pins [TIER_FULL] and behaves exactly as before.
 *
 * **No frame is ever dropped.** [process] always returns a frame. Tier changes take effect on the very
 * next frame — the resample is per-frame and in-process, so there is no extract restart, no pipeline
 * flush, and no gap in the output stream. (Retargeting the SDK extract *would* stall the stream; that
 * approach was rejected for exactly this reason.)
 *
 * Switching is rate-limited by [dwellUs] against the frame PTS (not wall-clock, so it is deterministic
 * and testable): a new tier must be continuously requested for the whole dwell window before it is
 * adopted, which absorbs signal noise and prevents resolution flapping.
 */
class DownscaleStage(
    /** Full-resolution tier — the 2K ERP target, and the pinned tier when the AI is disabled. */
    @JvmField var targetWidth: Int = TIER_FULL_W,
    @JvmField var targetHeight: Int = TIER_FULL_H,
    // The extract/source resolution the pipeline runs at — also the AI's top tier (the ceiling above
    // the 2K floor). Capped at 2240×1120 for real-time: the full 2.9K source (2880×1440) is 2.25× the
    // 2K pixel cost and drops capFps to ~9, whereas 2240×1120 (~1.36×) keeps live frame-rate usable
    // while still giving the AI headroom above 2K. Raise toward 2880 only once the resample is on GPU.
    @JvmField var sourceWidth: Int = 2240,
    @JvmField var sourceHeight: Int = 1120,
) : FrameStage {

    override val name: String = "Downscale"

    /**
     * Master switch for AI-driven tier selection. Off ⇒ the stage pins the full tier and passes frames
     * through untouched (the deterministic, pre-M3 behaviour) — the A/B arm for KPI capture.
     */
    @Volatile var adaptiveEnabled: Boolean = true

    /** A tier must be requested continuously for this long (frame-PTS time) before it is adopted. */
    @Volatile var dwellUs: Long = 2_500_000L // 2.5 s — responsive enough to demo, slow enough not to flap

    /** Currently active output tier. */
    @Volatile var activeWidth: Int = targetWidth
        private set

    @Volatile var activeHeight: Int = targetHeight
        private set

    // ── switch state ──────────────────────────────────────────────────────────────
    private var pendingW = 0
    private var pendingH = 0
    private var pendingSincePtsUs = 0L
    private var switches = 0L
    private var lastScale = 1f

    /** Reused output buffer — a fresh allocation per frame would churn GC at capture rate. */
    private var outBuf = ByteArray(0)

    // Cached column geometry: the source span each output column averages. Depends only on
    // (inW, outW), so it is built once per resolution change instead of per pixel per frame.
    private var colStart = IntArray(0)
    private var colCount = IntArray(0)
    private var colCacheInW = 0
    private var colCacheOutW = 0

    /** Source→extract pixel ratio (the SDK's GPU reduction; e.g. 0.44 for 2880×1440 → 1920×960). */
    val reductionRatio: Double
        get() {
            val src = (sourceWidth.toLong() * sourceHeight).coerceAtLeast(1)
            return (targetWidth.toLong() * targetHeight).toDouble() / src
        }

    /** Fraction of the source resolution actually delivered (2K floor ≈ 0.44 … 1.0 at full source). */
    val tierRatio: Double
        get() {
            val src = (sourceWidth.toLong() * sourceHeight).coerceAtLeast(1)
            return (activeWidth.toLong() * activeHeight).toDouble() / src
        }

    override fun process(frame: PipelineFrame, hints: PipelineHints): PipelineFrame {
        val scale = hints.perceptualScale
        if (!adaptiveEnabled || scale == null) {
            // Deterministic fall-open: pin the full tier. Adopt immediately (no dwell) so disabling the
            // AI restores full resolution at once rather than lingering on a reduced tier.
            lastScale = 1f
            pendingW = 0
            if (activeWidth != targetWidth || activeHeight != targetHeight) {
                activeWidth = targetWidth
                activeHeight = targetHeight
                switches++
            }
            return resampleTo(frame, activeWidth, activeHeight)
        }

        lastScale = scale
        val (wantW, wantH) = tierFor(scale)
        applyWithDwell(wantW, wantH, frame.ptsUs)
        return resampleTo(frame, activeWidth, activeHeight)
    }

    /**
     * Adopt [wantW]×[wantH] only once it has been requested continuously for [dwellUs]. Restarting the
     * pending window whenever the request changes gives hysteresis for free: a signal oscillating across
     * a tier boundary never accumulates a full dwell, so it never switches.
     */
    private fun applyWithDwell(wantW: Int, wantH: Int, ptsUs: Long) {
        if (wantW == activeWidth && wantH == activeHeight) {
            pendingW = 0 // already there — cancel any pending change
            return
        }
        if (wantW != pendingW || wantH != pendingH) {
            pendingW = wantW
            pendingH = wantH
            pendingSincePtsUs = ptsUs
            return
        }
        if (ptsUs - pendingSincePtsUs >= dwellUs) {
            activeWidth = wantW
            activeHeight = wantH
            pendingW = 0
            switches++
        }
    }

    /**
     * Maps the AI perceptual signal to an output tier in **[2K floor … source ceiling]** — the
     * capture-side resolution-normalisation target (Patent §2), with 2K as the guaranteed minimum.
     *
     * The signal `scale∈[0,1]` (higher = more perceptual detail/motion worth preserving) selects one of
     * up to four discrete 2:1 tiers between the 2K floor ([TIER_FULL_W]) and the live source width
     * ([sourceWidth]): a low signal normalises down to 2K (max reduction, min bandwidth); a high signal
     * keeps resolution near the source. It never returns below 2K and never above the source. Widths are
     * snapped to multiples of 32 so the halved height stays macroblock-aligned (÷16).
     */
    private fun tierFor(scale: Float): Pair<Int, Int> {
        val floorW = TIER_FULL_W                       // 1920 — hard 2K floor
        val ceilW = sourceWidth.coerceAtLeast(floorW)  // live source width, e.g. 2880 (never below floor)
        if (ceilW <= floorW) return floorW to TIER_FULL_H   // no headroom above 2K → pin the floor
        val s = scale.coerceIn(0f, 1f)
        val w = when {
            s < 0.25f -> floorW                        // static / low detail → normalise to 2K
            s < 0.50f -> lerp32(floorW, ceilW, 1f / 3f)
            s < 0.75f -> lerp32(floorW, ceilW, 2f / 3f)
            else -> ceilW                              // rich detail / motion → keep the full source
        }
        return w to (w / 2)
    }

    /** Linear interpolate floor→ceil at fraction [t], snapped to a multiple of 32 (so width/2 is ÷16). */
    private fun lerp32(floorW: Int, ceilW: Int, t: Float): Int {
        val w = floorW + ((ceilW - floorW) * t).toInt()
        return ((w / 32) * 32).coerceIn(floorW, ceilW)
    }

    /** Rebuild the per-column source spans; a no-op unless the in/out width pair changed. */
    private fun ensureColumnTable(inW: Int, outW: Int) {
        if (colCacheInW == inW && colCacheOutW == outW) return
        if (colStart.size < outW) {
            colStart = IntArray(outW)
            colCount = IntArray(outW)
        }
        for (ox in 0 until outW) {
            val s0 = (ox.toLong() * inW / outW).toInt()
            val s1 = maxOf(s0 + 1, ((ox + 1).toLong() * inW / outW).toInt())
            colStart[ox] = s0
            colCount[ox] = s1 - s0
        }
        colCacheInW = inW
        colCacheOutW = outW
    }

    /**
     * Deterministic area-average (box filter) to [outW]×[outH]. Returns [frame] untouched when it is
     * already at the target — the common case at the full tier, so the pinned path costs nothing.
     *
     * Each output pixel averages the source rectangle that maps onto it, so every source pixel is read
     * exactly once. That is correct for arbitrary (non-integer) ratios and avoids the aliasing a plain
     * nearest/bilinear sample would introduce when downscaling.
     *
     * **Cost.** The naive form spends five integer divisions per output pixel (two deriving the column
     * span, three averaging the channels) — ~4M divisions per frame at the mid tier, which dominated the
     * runtime. Both are removed here: column spans come from a table cached per resolution
     * ([ensureColumnTable]), and the channel average uses a reciprocal multiply-shift ([RECIP]) that is
     * *exact* over the whole accumulator range (see [RECIP_SHIFT]). The loop is then memory-bound.
     */
    private fun resampleTo(frame: PipelineFrame, outW: Int, outH: Int): PipelineFrame {
        val inW = frame.width
        val inH = frame.height
        if (inW == outW && inH == outH) return frame
        if (outW <= 0 || outH <= 0 || inW <= 0 || inH <= 0) return frame
        if (outW > inW || outH > inH) return frame // never upscale — that would invent detail

        val need = outW * outH * 4
        if (outBuf.size < need) outBuf = ByteArray(need)
        ensureColumnTable(inW, outW)

        val src = frame.pixels
        val dst = outBuf
        val srcStride = inW * 4
        val cStart = colStart
        val cCount = colCount

        var di = 0
        for (oy in 0 until outH) {
            val sy0 = (oy.toLong() * inH / outH).toInt()
            val sy1 = maxOf(sy0 + 1, ((oy + 1).toLong() * inH / outH).toInt())
            val boxH = sy1 - sy0
            val rowOrigin = sy0 * srcStride
            for (ox in 0 until outW) {
                val boxW = cCount[ox]
                var rowBase = rowOrigin + cStart[ox] * 4
                var r = 0
                var g = 0
                var b = 0
                for (row in 0 until boxH) {
                    var si = rowBase
                    for (col in 0 until boxW) {
                        r += src[si].toInt() and 0xFF
                        g += src[si + 1].toInt() and 0xFF
                        b += src[si + 2].toInt() and 0xFF
                        si += 4
                    }
                    rowBase += srcStride
                }
                val n = boxW * boxH
                if (n <= MAX_BOX) {
                    val recip = RECIP[n]
                    dst[di] = ((r * recip) shr RECIP_SHIFT).toByte()
                    dst[di + 1] = ((g * recip) shr RECIP_SHIFT).toByte()
                    dst[di + 2] = ((b * recip) shr RECIP_SHIFT).toByte()
                } else { // pathological ratio — correctness over speed
                    dst[di] = (r / n).toByte()
                    dst[di + 1] = (g / n).toByte()
                    dst[di + 2] = (b / n).toByte()
                }
                dst[di + 3] = 255.toByte()
                di += 4
            }
        }

        frame.pixels = dst
        frame.width = outW
        frame.height = outH
        return frame
    }

    /** KPI readout for `getPipelineMetrics()` / the logcat monitor. */
    fun stats(): Map<String, Any> = mapOf(
        "spatialAdaptive" to adaptiveEnabled,
        "spatialWidth" to activeWidth,
        "spatialHeight" to activeHeight,
        "spatialTierRatio" to tierRatio,
        "spatialSourceRatio" to reductionRatio,
        "spatialSwitches" to switches,
        "spatialLastScale" to lastScale,
    )

    /** Reset to the full tier (used on stream restart so a new session starts unreduced). */
    fun reset() {
        activeWidth = targetWidth
        activeHeight = targetHeight
        pendingW = 0
        pendingSincePtsUs = 0
        switches = 0
        lastScale = 1f
    }

    companion object {
        /**
         * Reciprocal multiply-shift replacing the per-pixel channel division: `sum / n` becomes
         * `(sum * RECIP[n]) shr RECIP_SHIFT`.
         *
         * Shift 21 is the smallest that is **exact** for every `n` in `1..MAX_BOX` across the entire
         * accumulator range (`sum ≤ n * 255`) — verified exhaustively; shifts ≤ 19 are not (they
         * mis-round, e.g. n=43). The largest intermediate product is ~535M, comfortably inside Int32
         * (~2.15G), so the multiply cannot overflow.
         */
        private const val RECIP_SHIFT = 21
        private const val MAX_BOX = 64
        private val RECIP = IntArray(MAX_BOX + 1) { n ->
            if (n == 0) 0 else (1 shl RECIP_SHIFT) / n + 1
        }

        // The 2K ERP **floor** — the minimum delivered resolution (the pipeline never goes below this)
        // and the tier the stage pins when the AI is disabled. 2:1 aspect, encoder-macroblock friendly.
        const val TIER_FULL_W = 1920
        const val TIER_FULL_H = 960
    }
}
