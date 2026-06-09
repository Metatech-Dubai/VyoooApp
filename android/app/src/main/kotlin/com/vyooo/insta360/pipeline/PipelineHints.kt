package com.vyooo.insta360.pipeline

/**
 * Optional decision signals for the pipeline — metadata only, no pixel data. An on-device AI layer
 * may supply these; the pipeline runs fully when a hint is `null` (each field is nullable and stages
 * treat `null` as "use the deterministic default").
 */
interface PipelineHints {
    /** Stabilised forward direction θ₀ (degrees); `null` → use the frame default. */
    val forwardThetaDeg: Float?

    /** Classification override for panoramic-vs-planar; `null` → let the detector decide. */
    val isPanoramic: Boolean?

    /** Perceptual-salience hint guiding the downscale target; `null` → fixed target. */
    val perceptualScale: Float?

    /** Motion metric in [0,1] for temporal gating; `null` → the stage computes its own. */
    val motion: Float?
}

/** Defaults with no AI: every hint absent, so stages use deterministic behaviour. */
object DeterministicHints : PipelineHints {
    override val forwardThetaDeg: Float? = null
    override val isPanoramic: Boolean? = null
    override val perceptualScale: Float? = null
    override val motion: Float? = null
}

/**
 * Live-updatable hints written by an on-device AI layer and read by the pipeline once per frame.
 * Only what the AI sets is applied; everything left `null` falls back to deterministic logic.
 */
class MutableHints : PipelineHints {
    @Volatile override var forwardThetaDeg: Float? = null
    @Volatile override var isPanoramic: Boolean? = null
    @Volatile override var perceptualScale: Float? = null
    @Volatile override var motion: Float? = null
}
