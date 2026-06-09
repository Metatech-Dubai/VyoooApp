package com.vyooo.insta360.pipeline

/**
 * A single deterministic transformation in the capture-side pipeline.
 *
 * Implementations are deterministic (Patent: AI only *guides* parameters, it never performs the
 * transform). A stage returns the (possibly mutated) frame, or `null` to **drop** it — used by the
 * temporal-dedup stage (Milestone 2) to enforce the 1-in-N frame budget.
 */
interface FrameStage {
    val name: String

    /** Transform [frame] using optional [hints]; return it, or `null` to drop the frame. */
    fun process(frame: PipelineFrame, hints: PipelineHints): PipelineFrame?
}
