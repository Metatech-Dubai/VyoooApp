import Foundation

/// The capture-side, pre-encoding optimisation pipeline. Swift port of Android `FramePipeline.kt`.
///
/// Runs an ordered list of deterministic `FrameStage`s on each captured frame, upstream of the
/// encoder. A stage may drop a frame (return `nil`); the pipeline then stops and reports the drop.
/// If a stage throws, the error is logged and the frame passes through unchanged, so the pipeline
/// never crashes the capture path.
///
/// Default chain: Downscale → PanoramaDetect → ForwardMask → TemporalDedup. AI hints are supplied via
/// `PipelineHints`; `DeterministicHints` runs the pipeline with no AI.
final class FramePipeline {

    private let stages: [FrameStage]
    private let hints: PipelineHints
    let metrics = PipelineMetrics()

    init(stages: [FrameStage], hints: PipelineHints = DeterministicHints.shared) {
        self.stages = stages
        self.hints = hints
    }

    /// Returns the processed frame, or `nil` if a stage dropped it.
    func process(_ frame: PipelineFrame) -> PipelineFrame? {
        let inW = frame.width
        let inH = frame.height
        let t0 = DispatchTime.now().uptimeNanoseconds
        var current = frame
        for stage in stages {
            let s0 = DispatchTime.now().uptimeNanoseconds
            let result: PipelineFrame?
            do {
                result = try stage.process(current, hints: hints)
            } catch {
                NSLog("[FramePipeline] stage '\(stage.name)' failed; falling open (pass-through): \(error)")
                result = current // fall open
            }
            metrics.recordStage(stage.name, nanos: DispatchTime.now().uptimeNanoseconds - s0)
            guard let next = result else {
                metrics.recordDropped()
                return nil
            }
            current = next
        }
        metrics.recordFrame(inW: inW, inH: inH, outW: current.width, outH: current.height,
                            totalNanos: DispatchTime.now().uptimeNanoseconds - t0)
        return current
    }
}
