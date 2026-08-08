import Foundation

/// A single deterministic transformation in the capture-side pipeline.
/// Swift port of Android `FrameStage.kt`.
///
/// AI may guide parameters, but a stage always performs the transform itself. A stage returns the
/// (possibly mutated) frame, or `nil` to drop it (e.g. the temporal-dedup stage enforcing a frame
/// budget).
protocol FrameStage: AnyObject {
    var name: String { get }

    /// Transform `frame` using optional `hints`; return it, or `nil` to drop the frame.
    /// Declared `throws` so `FramePipeline` can fall open (pass-through) on any stage error, mirroring
    /// the Android try/catch. Concrete stages that never throw simply omit `throws`.
    func process(_ frame: PipelineFrame, hints: PipelineHints) throws -> PipelineFrame?
}
