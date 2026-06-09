package com.vyooo.insta360.pipeline

/**
 * Per-frame decision metadata produced by pipeline stages (and, in Milestone 3, by AI hints).
 *
 * Metadata only — never pixel data. Stages read/write these fields to coordinate (e.g.
 * [com.vyooo.insta360.pipeline.PanoramaDetectStage] sets [isPanoramic], which
 * [com.vyooo.insta360.pipeline.ForwardMaskStage] reads to decide the planar bypass).
 */
class FrameMeta(
    /** Whether the frame is panoramic (ERP). `null` until [PanoramaDetectStage] runs. */
    @JvmField var isPanoramic: Boolean? = null,
    /** Forward viewing direction θ₀ in degrees (0 = ERP centre). Stabilised by AI in M3. */
    @JvmField var forwardThetaDeg: Float = 0f,
)
