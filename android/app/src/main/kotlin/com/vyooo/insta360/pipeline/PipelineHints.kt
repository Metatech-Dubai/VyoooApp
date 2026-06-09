package com.vyooo.insta360.pipeline

/**
 * Side-channel decision signals for the pipeline (Patent "Optional AI Assistance").
 *
 * **Metadata only — no pixel data ever passes through here.** Milestone 1 uses [DeterministicHints]
 * (no AI); Milestone 3 supplies an AI-backed implementation. The pipeline must run fully ("fall
 * open") when hints are absent/`null`, so every field is nullable and stages treat `null` as
 * "use the deterministic default".
 */
interface PipelineHints {
    /** Stabilised forward direction θ₀ (degrees); `null` → use the frame's default. (M3) */
    val forwardThetaDeg: Float?

    /** Classification override for panoramic-vs-planar; `null` → let the detector decide. (M3) */
    val isPanoramic: Boolean?

    // Perceptual hints (downscale) and motion hints (temporal dedup) are added in M2/M3.
}

/** No-AI defaults used in Milestone 1: every hint absent, so stages use deterministic behaviour. */
object DeterministicHints : PipelineHints {
    override val forwardThetaDeg: Float? = null
    override val isPanoramic: Boolean? = null
}
