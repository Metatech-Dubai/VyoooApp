package com.vyooo.insta360.pipeline

/**
 * A single deterministic transformation in the capture-side pipeline.
 *
 * AI may guide parameters, but a stage always performs the transform itself. A stage returns the
 * (possibly mutated) frame, or `null` to drop it (e.g. the temporal-dedup stage enforcing a 1-in-N
 * frame budget).
 */
interface FrameStage {
    val name: String

    /** Transform [frame] using optional [hints]; return it, or `null` to drop the frame. */
    fun process(frame: PipelineFrame, hints: PipelineHints): PipelineFrame?
}
