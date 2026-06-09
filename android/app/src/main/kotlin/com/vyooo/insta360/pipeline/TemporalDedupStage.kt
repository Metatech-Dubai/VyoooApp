package com.vyooo.insta360.pipeline

/**
 * Temporal redundancy reduction (Patent §5) — **Milestone 2 placeholder**.
 *
 * The full stage will transmit no more than one frame per N (N ≥ 2), governed by deterministic
 * scheduling and motion gating (low-cost pixel-difference, optionally AI-assisted), while never
 * dropping audio and keeping video timestamps monotonic. It would return `null` to drop a frame.
 *
 * For Milestone 1 it is a no-op pass-through so the pipeline shape matches the patent architecture
 * without yet changing frame cadence.
 */
class TemporalDedupStage : FrameStage {

    override val name: String = "TemporalDedup"

    override fun process(frame: PipelineFrame, hints: PipelineHints): PipelineFrame {
        // M2: deterministic 1-in-N selection + motion gating → may return null to drop.
        return frame
    }
}
