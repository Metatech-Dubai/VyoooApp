package com.vyooo.insta360.pipeline

/**
 * Panoramic-vs-planar detection (Patent §3).
 *
 * Determines whether the frame is panoramic (equirectangular) so the forward-mask stage can apply
 * (or be bypassed for planar input). For this POC the source is always the Insta360 stitched ERP, so
 * detection is a **deterministic geometric heuristic**: a ~2:1 aspect ratio ⇒ panoramic. An explicit
 * AI classifier is Milestone 3 (supplied via [PipelineHints.isPanoramic]); when absent we fall open
 * to the heuristic.
 *
 * The planar-bypass branch is intentionally preserved even though the Insta360 path never takes it.
 */
class PanoramaDetectStage : FrameStage {

    override val name: String = "PanoramaDetect"

    override fun process(frame: PipelineFrame, hints: PipelineHints): PipelineFrame {
        frame.meta.isPanoramic = hints.isPanoramic ?: isErpAspect(frame.width, frame.height)
        return frame
    }

    /** True when width:height is ~2:1 (ERP), with tolerance. */
    private fun isErpAspect(width: Int, height: Int): Boolean {
        if (height <= 0) return false
        val ratio = width.toDouble() / height
        return ratio in (2.0 - ASPECT_TOLERANCE)..(2.0 + ASPECT_TOLERANCE)
    }

    private companion object {
        const val ASPECT_TOLERANCE = 0.15 // accept ~1.85:1 .. 2.15:1 as ERP
    }
}
