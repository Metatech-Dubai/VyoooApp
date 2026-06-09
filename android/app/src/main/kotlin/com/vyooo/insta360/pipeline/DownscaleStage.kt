package com.vyooo.insta360.pipeline

/**
 * Capture-side resolution normalisation — 8K/4K → 2K (Patent §2).
 *
 * **Realisation in this POC:** the actual GPU downscale is performed upstream by the Insta360 SDK's
 * `startExtractMediaFrame(W_t, H_t, …)`, which extracts the stitched ERP at our chosen target
 * resolution on the GPU (Patent §2: "hardware-accelerated or GPU-based scaling"). This stage is the
 * **authority + recorder** for that target: it owns the target dimensions and reports the
 * source→target reduction, keeping the patent stage explicit and tunable.
 *
 * For non-SDK / planar inputs (a future extension) this stage would perform an explicit deterministic
 * downscale here; for M1 the incoming frame is already at the target resolution, so it passes through.
 *
 * Aspect ratio is preserved (Patent §2: `W_t < W_in`, ratio preserved).
 */
class DownscaleStage(
    /** Target width/height set on the SDK extract (the 2K target). */
    @JvmField var targetWidth: Int = 1920,
    @JvmField var targetHeight: Int = 960,
    /** Source live-stream resolution for reporting (Insta360 X4 live stream ≈ 2880×1440). */
    @JvmField var sourceWidth: Int = 2880,
    @JvmField var sourceHeight: Int = 1440,
) : FrameStage {

    override val name: String = "Downscale"

    /** Source→target pixel ratio (e.g. 0.44 for 2880×1440 → 1920×960). */
    val reductionRatio: Double
        get() {
            val src = (sourceWidth.toLong() * sourceHeight).coerceAtLeast(1)
            return (targetWidth.toLong() * targetHeight).toDouble() / src
        }

    override fun process(frame: PipelineFrame, hints: PipelineHints): PipelineFrame {
        // The SDK already delivered the frame at the extract target. If a future source ever delivers
        // a larger frame, an explicit deterministic downscale would happen here. No-op for M1.
        return frame
    }
}
