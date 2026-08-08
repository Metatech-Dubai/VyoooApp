import Foundation

/// Optional decision signals for the pipeline — metadata only, no pixel data. An on-device AI layer
/// may supply these; the pipeline runs fully when a hint is `nil`. Swift port of Android
/// `PipelineHints.kt` (interface + `DeterministicHints` + `MutableHints`).
protocol PipelineHints: AnyObject {
    /// Stabilised forward direction θ₀ (degrees); `nil` → use the frame default.
    var forwardThetaDeg: Float? { get }
    /// Classification override for panoramic-vs-planar; `nil` → let the detector decide.
    var isPanoramic: Bool? { get }
    /// Perceptual-salience hint guiding the downscale target; `nil` → fixed target.
    var perceptualScale: Float? { get }
    /// Motion metric in [0,1] for temporal gating; `nil` → the stage computes its own.
    var motion: Float? { get }
}

/// Defaults with no AI: every hint absent, so stages use deterministic behaviour.
final class DeterministicHints: PipelineHints {
    static let shared = DeterministicHints()
    var forwardThetaDeg: Float? { nil }
    var isPanoramic: Bool? { nil }
    var perceptualScale: Float? { nil }
    var motion: Float? { nil }
}

/// Live-updatable hints written by the on-device AI layer and read by the pipeline once per frame.
/// Only what the AI sets is applied; everything left `nil` falls back to deterministic logic.
final class MutableHints: PipelineHints {
    var forwardThetaDeg: Float?
    var isPanoramic: Bool?
    var perceptualScale: Float?
    var motion: Float?
}
