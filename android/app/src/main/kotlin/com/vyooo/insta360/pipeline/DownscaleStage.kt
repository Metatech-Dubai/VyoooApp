package com.vyooo.insta360.pipeline

/**
 * Capture-side resolution normalisation (8K/4K → 2K).
 *
 * The actual scaling is performed upstream by the Insta360 SDK's `startExtractMediaFrame(W_t, H_t, …)`,
 * which extracts the stitched ERP at the chosen target resolution on the GPU. This stage owns that
 * target and reports the source→target reduction; the incoming frame already arrives at the target
 * resolution, so it passes through. (For a non-SDK / planar source it would downscale here.)
 *
 * Aspect ratio is preserved (`W_t < W_in`).
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
        // Frame already arrives at the extract target; an explicit downscale would go here for a
        // larger source. Pass through.
        return frame
    }
}
