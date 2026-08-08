import Foundation

/// Per-frame decision metadata produced by pipeline stages (and by AI hints when present).
/// Swift port of Android `FrameMeta.kt` — metadata only, never pixel data.
final class FrameMeta {
    /// Whether the frame is panoramic (ERP). `nil` until `PanoramaDetectStage` runs.
    var isPanoramic: Bool?
    /// Forward viewing direction θ₀ in degrees (0 = ERP centre). Stabilised by AI when present.
    var forwardThetaDeg: Float

    init(isPanoramic: Bool? = nil, forwardThetaDeg: Float = 0) {
        self.isPanoramic = isPanoramic
        self.forwardThetaDeg = forwardThetaDeg
    }
}

/// One frame flowing through the capture-side optimisation pipeline.
/// Swift port of Android `PipelineFrame.kt`.
///
/// Pixels are **RGBA8888**, row-major, tightly packed (`pixels.count == width * height * 4`). Stages
/// may mutate `pixels` in place (e.g. `ForwardMaskStage`) or replace it (e.g. `DownscaleStage`).
/// `ptsUs` is the capture presentation timestamp and MUST be preserved unchanged through every stage
/// to keep timestamp integrity / A-V sync.
final class PipelineFrame {
    var pixels: [UInt8]
    var width: Int
    var height: Int
    var ptsUs: Int64
    let meta: FrameMeta

    init(pixels: [UInt8], width: Int, height: Int, ptsUs: Int64, meta: FrameMeta = FrameMeta()) {
        self.pixels = pixels
        self.width = width
        self.height = height
        self.ptsUs = ptsUs
        self.meta = meta
    }
}
