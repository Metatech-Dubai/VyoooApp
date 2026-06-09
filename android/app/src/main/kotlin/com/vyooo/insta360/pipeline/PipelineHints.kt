package com.vyooo.insta360.pipeline

/**
 * Side-channel decision signals for the pipeline (Patent "Optional AI Assistance").
 *
 * **Metadata only — no pixel data ever passes through here.** Milestone 1 uses [DeterministicHints]
 * (no AI); Milestone 3 supplies an AI-backed implementation ([MutableHints], updated live by the
 * on-device AI layer). The pipeline must run fully ("fall open") when a hint is `null`, so every
 * field is nullable and stages treat `null` as "use the deterministic default".
 */
interface PipelineHints {
    /** Stabilised forward direction θ₀ (degrees); `null` → use the frame default. (M3 / ForwardMask) */
    val forwardThetaDeg: Float?

    /** Classification override for panoramic-vs-planar; `null` → let the detector decide. (M3 / PanoramaDetect) */
    val isPanoramic: Boolean?

    /** Perceptual-salience hint guiding the downscale target; `null` → fixed target. (M3 / Downscale) */
    val perceptualScale: Float?

    /** Motion metric ∈ [0,1] for temporal gating; `null` → the stage computes its own. (M2–M3 / TemporalDedup) */
    val motion: Float?
}

/** No-AI defaults (Milestone 1): every hint absent, so stages use deterministic behaviour. */
object DeterministicHints : PipelineHints {
    override val forwardThetaDeg: Float? = null
    override val isPanoramic: Boolean? = null
    override val perceptualScale: Float? = null
    override val motion: Float? = null
}

/**
 * Live-updatable hints written by the on-device AI layer (Milestone 3) and read by the pipeline once
 * per frame. The AI sets only what it has; everything left `null` falls open to deterministic logic.
 */
class MutableHints : PipelineHints {
    @Volatile override var forwardThetaDeg: Float? = null
    @Volatile override var isPanoramic: Boolean? = null
    @Volatile override var perceptualScale: Float? = null
    @Volatile override var motion: Float? = null
}
