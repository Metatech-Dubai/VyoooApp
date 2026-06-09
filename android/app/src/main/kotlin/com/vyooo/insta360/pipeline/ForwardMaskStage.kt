package com.vyooo.insta360.pipeline

/**
 * Forward-only panoramic retention (Patent §4).
 *
 * Keeps a forward angular field of view [forwardFovDeg] (≈180–220°, default 200°) of the
 * equirectangular frame and suppresses the rear to a neutral value (opaque black), with an optional
 * feathered boundary [featherDeg] to reduce visual discontinuity.
 *
 * **ERP geometry:** the horizontal axis is longitude θ ∈ [−180°, +180°] mapped linearly to columns
 * x ∈ [0, W). The forward direction θ₀ (default 0) is the centre column; the rear (±180°) is at the
 * left/right edges. So forward retention keeps a centred horizontal band of width `(F/360)·W` and
 * blacks out the two edge bands. Deterministic; AI may stabilise θ₀ over time (M3) but must not
 * change the field size (Patent §4).
 *
 * Per-column suppression factors are precomputed and cached (recomputed only when the geometry
 * changes), so the per-frame cost is: kept columns skipped, suppressed columns set to black, and a
 * thin feather band multiplied — comfortably real-time at 2K/30 fps on CPU.
 */
class ForwardMaskStage(
    @JvmField var forwardFovDeg: Float = 200f,
    @JvmField var featherDeg: Float = 6f,
) : FrameStage {

    override val name: String = "ForwardMask"

    /** Fraction of the horizontal field retained (e.g. 200/360 ≈ 0.56). For reporting. */
    val retainedFraction: Float
        get() = (forwardFovDeg / 360f).coerceIn(0f, 1f)

    // Cached per-column factor table (1.0 keep … 0.0 suppress, with feather ramp).
    private var cachedFactors: FloatArray? = null
    private var cachedWidth = -1
    private var cachedFov = -1f
    private var cachedFeather = -1f
    private var cachedTheta = Float.NaN

    override fun process(frame: PipelineFrame, hints: PipelineHints): PipelineFrame {
        // Planar bypass (Patent §3/§4): never mask non-panoramic input.
        if (frame.meta.isPanoramic == false) return frame

        val keepFrac = retainedFraction
        if (keepFrac >= 1f) return frame // full 360° retained → nothing to suppress

        val w = frame.width
        val h = frame.height
        if (w <= 0 || h <= 0) return frame
        if (frame.pixels.size < w * h * 4) return frame

        val theta0 = hints.forwardThetaDeg ?: frame.meta.forwardThetaDeg
        val factors = factorTable(w, keepFrac, theta0)

        val px = frame.pixels
        var rowBase = 0
        val stride = w * 4
        for (y in 0 until h) {
            var i = rowBase
            for (x in 0 until w) {
                val f = factors[x]
                when {
                    f >= 1f -> { /* kept — leave pixel untouched */ }
                    f <= 0f -> {
                        // suppressed → opaque black
                        px[i] = 0; px[i + 1] = 0; px[i + 2] = 0; px[i + 3] = 255.toByte()
                    }
                    else -> {
                        // feather ramp toward black; alpha kept opaque
                        px[i] = ((px[i].toInt() and 0xFF) * f).toInt().toByte()
                        px[i + 1] = ((px[i + 1].toInt() and 0xFF) * f).toInt().toByte()
                        px[i + 2] = ((px[i + 2].toInt() and 0xFF) * f).toInt().toByte()
                        px[i + 3] = 255.toByte()
                    }
                }
                i += 4
            }
            rowBase += stride
        }
        return frame
    }

    /** Per-column keep factor in [0,1], centred on θ₀, with a feather ramp at the kept-region edges. */
    private fun factorTable(width: Int, keepFrac: Float, theta0: Float): FloatArray {
        val cached = cachedFactors
        if (cached != null && cachedWidth == width && cachedFov == forwardFovDeg &&
            cachedFeather == featherDeg && cachedTheta == theta0
        ) {
            return cached
        }

        val factors = FloatArray(width)
        val centerX = width / 2f + (theta0 / 360f) * width
        val halfKeep = keepFrac * width / 2f
        val left = centerX - halfKeep
        val right = centerX + halfKeep
        val featherPx = (featherDeg / 360f * width).coerceAtLeast(0f)

        for (x in 0 until width) {
            val xc = x + 0.5f
            factors[x] = when {
                xc < left || xc > right -> 0f
                featherPx <= 0f -> 1f
                else -> {
                    val dEdge = minOf(xc - left, right - xc) // distance into kept region
                    (dEdge / featherPx).coerceIn(0f, 1f)
                }
            }
        }

        cachedFactors = factors
        cachedWidth = width
        cachedFov = forwardFovDeg
        cachedFeather = featherDeg
        cachedTheta = theta0
        return factors
    }
}
