package com.vyooo.insta360.pipeline

/**
 * Temporal redundancy reduction — not yet implemented.
 *
 * Will transmit no more than one frame per N (N ≥ 2), governed by deterministic scheduling and
 * motion gating (low-cost pixel-difference, optionally AI-assisted), never dropping audio and keeping
 * video timestamps monotonic; it returns `null` to drop a frame. Currently a no-op pass-through.
 */
class TemporalDedupStage : FrameStage {

    override val name: String = "TemporalDedup"

    override fun process(frame: PipelineFrame, hints: PipelineHints): PipelineFrame {
        // TODO: deterministic 1-in-N selection + motion gating → return null to drop a frame.
        return frame
    }
}
