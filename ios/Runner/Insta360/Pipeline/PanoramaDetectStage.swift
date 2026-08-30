import Foundation

/// Panoramic-vs-planar detection. Swift port of Android `PanoramaDetectStage.kt`.
///
/// Determines whether the frame is panoramic (equirectangular) so the forward-mask stage applies (or
/// is bypassed for planar input). Detection is a deterministic geometric heuristic: a ~2:1 aspect
/// ratio ⇒ panoramic. An AI classifier may override via `PipelineHints.isPanoramic`.
final class PanoramaDetectStage: FrameStage {

    let name = "PanoramaDetect"

    func process(_ frame: PipelineFrame, hints: PipelineHints) -> PipelineFrame? {
        frame.meta.isPanoramic = hints.isPanoramic ?? Self.isErpAspect(frame.width, frame.height)
        return frame
    }

    /// True when width:height is ~2:1 (ERP), with tolerance.
    private static func isErpAspect(_ width: Int, _ height: Int) -> Bool {
        if height <= 0 { return false }
        let ratio = Double(width) / Double(height)
        return ratio >= (2.0 - aspectTolerance) && ratio <= (2.0 + aspectTolerance)
    }

    private static let aspectTolerance = 0.15 // accept ~1.85:1 .. 2.15:1 as ERP
}
