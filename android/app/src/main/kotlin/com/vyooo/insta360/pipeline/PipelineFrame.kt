package com.vyooo.insta360.pipeline

/**
 * One frame flowing through the capture-side optimisation pipeline.
 *
 * Pixels are **RGBA8888**, row-major, tightly packed (`pixels.size == width * height * 4`). Stages
 * may mutate [pixels] in place (e.g. [ForwardMaskStage]) or replace it (e.g. an explicit downscale).
 * [ptsUs] is the capture presentation timestamp and must be preserved unchanged through every stage
 * to keep timestamp integrity / A-V sync (Patent §1).
 */
class PipelineFrame(
    @JvmField var pixels: ByteArray,
    @JvmField var width: Int,
    @JvmField var height: Int,
    @JvmField var ptsUs: Long,
    @JvmField val meta: FrameMeta = FrameMeta(),
)
