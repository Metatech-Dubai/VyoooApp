import Foundation
import CoreVideo

/// The single insertion point + processing hub for extracted Insta360 flat-pano (ERP) frames.
/// iOS mirror of the Android `Insta360FrameSink` object — now running the SAME capture-side
/// optimisation pipeline (Downscale → PanoramaDetect → ForwardMask → TemporalDedup, fed by the
/// heuristic AI decision layer).
///
/// One deterministic processing path:
/// ```
/// BGRA CVPixelBuffer → RGBA → HeuristicDecisionLayer.observe → FramePipeline
///      ├─► onProcessedFrame (host display — BGRA CVPixelBuffer for the Flutter texture)
///      └─► onFrame          (encoder / transport — RGBA; when streamingEnabled)
/// ```
/// A stage may drop a frame (pipeline returns nil) — nothing is forwarded for that frame, so display
/// and transmitted stream stay in lock-step (identical to Android).
final class Insta360FrameSink {

    static let shared = Insta360FrameSink()

    // ── Pipeline (single source of truth, mirrors Android Insta360FrameSink) ─────
    private let downscale = DownscaleStage()
    private let forwardMask = ForwardMaskStage()
    private let temporalDedup = TemporalDedupStage()
    /// AI-fed decision hints; deterministic (all nil) until the decision layer writes them.
    let hints = MutableHints()
    /// M3 bounded heuristic decision layer — writes decision signals into `hints` (metadata only).
    let decisionLayer: HeuristicDecisionLayer
    let pipeline: FramePipeline

    private let pixelFactory = PixelBufferFactory()

    private init() {
        decisionLayer = HeuristicDecisionLayer(hints: hints)
        pipeline = FramePipeline(
            stages: [downscale, PanoramaDetectStage(), forwardMask, temporalDedup],
            hints: hints
        )
    }

    private let lock = NSLock()

    // ── Fan-out sinks (set by the bridge / texture) ─────────────────────────────
    /// Processed BGRA pixel buffer for the host texture.
    var onProcessedFrame: ((CVPixelBuffer, Int64) -> Void)?
    /// Processed RGBA (w*h*4) for the encoder/transport. Only invoked while `streamingEnabled`.
    var onFrame: ((Data, Int, Int, Int64) -> Void)?
    /// (width, height, fps, totalCount) — emitted ~1×/sec.
    var onStats: ((Int, Int, Int, Int64) -> Void)?

    var streamingEnabled = false

    // ── Pipeline toggles (now wired to the real stages) ─────────────────────────
    /// Live masked/unmasked toggle (forward-only suppression on/off).
    func setMaskEnabled(_ v: Bool) { forwardMask.enabled = v }
    /// Live temporal-reduction toggle (motion-gated static pacing on/off) — A/B / KPI capture.
    func setTemporalEnabled(_ v: Bool) { temporalDedup.enabled = v }
    /// Live AI decision-layer toggle (off = deterministic fall-open) — A/B / KPI capture.
    func setAiEnabled(_ v: Bool) { decisionLayer.enabled = v }

    // ── Stats window (mirrors Android FrameSink; drives the frameStats event) ────
    private var count: Int64 = 0
    private var windowStartNs: UInt64 = 0
    private var framesThisWindow = 0
    private var lastFps = 0
    private var baseTimestamp: TimeInterval = 0
    private var lastTransmitNs: UInt64 = 0

    /// Cap the transmit copy rate (mirrors Android's 24 fps ceiling).
    private let transmitMinIntervalNs: UInt64 = 1_000_000_000 / 24

    func reset() {
        lock.lock()
        count = 0; windowStartNs = 0; framesThisWindow = 0; lastFps = 0
        baseTimestamp = 0; lastTransmitNs = 0
        lock.unlock()
        pipeline.metrics.reset()
        downscale.reset()
        temporalDedup.reset()
        decisionLayer.reset()
    }

    /// Live metrics: FrameSink fps/framesOut, then the real pipeline snapshot + per-stage stats.
    /// Emits the identical keys Android does — `fps, framesIn, framesOut, framesDropped, totalMs,
    /// spatialReduction, stagesMs` (from the pipeline), plus the Downscale/Temporal/AI KPI fields.
    func metrics() -> [String: Any] {
        lock.lock()
        let fps = lastFps
        let framesOut = count
        lock.unlock()
        var m: [String: Any] = [:]
        m["fps"] = fps
        m["framesOut"] = framesOut
        m.merge(pipeline.metrics.snapshot()) { _, new in new }
        m.merge(downscale.stats()) { _, new in new }
        m.merge(temporalDedup.stats()) { _, new in new }
        m.merge(decisionLayer.stats()) { _, new in new }
        return m
    }

    /// Submit one stitched ERP frame. `pixelBuffer` is BGRA (`kCVPixelFormatType_32BGRA`).
    /// `timestamp` is the SDK video-frame timestamp (seconds). Called serially on the flat-pano queue.
    func submit(pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) {
        let w = CVPixelBufferGetWidth(pixelBuffer)
        let h = CVPixelBufferGetHeight(pixelBuffer)
        guard w > 0, h > 0 else { return }
        guard var rgba = Self.bgraToRgba(pixelBuffer) else { return }

        let now = DispatchTime.now().uptimeNanoseconds
        lock.lock()
        if baseTimestamp == 0 { baseTimestamp = timestamp }
        let ptsUs = Int64((timestamp - baseTimestamp) * 1_000_000)
        lock.unlock()

        // M3: the decision layer observes this frame and writes decision signals (metadata) into
        // `hints` BEFORE the pipeline runs, so the stages read fresh AI-assisted hints this frame.
        decisionLayer.observe(rgba, width: w, height: h)

        let frame = PipelineFrame(pixels: rgba, width: w, height: h, ptsUs: ptsUs)
        // Drop this local's reference to the pixel storage so `frame.pixels` is uniquely owned — the
        // in-place ForwardMask mutation then avoids a copy-on-write copy at the full tier.
        rgba = []
        guard let result = pipeline.process(frame) else {
            return // dropped by a stage (e.g. temporal dedup) — metrics already recorded the drop
        }
        let outW = result.width
        let outH = result.height

        // fps over a 1-second sliding window (post-pipeline output rate).
        lock.lock()
        count += 1
        if windowStartNs == 0 { windowStartNs = now }
        framesThisWindow += 1
        var emitStats: (Int, Int, Int, Int64)?
        if now - windowStartNs >= 1_000_000_000 {
            lastFps = framesThisWindow
            framesThisWindow = 0
            windowStartNs = now
            emitStats = (outW, outH, lastFps, count)
        }
        let streaming = streamingEnabled
        let shouldTransmit = streaming && (now - lastTransmitNs >= transmitMinIntervalNs)
        if shouldTransmit { lastTransmitNs = now }
        let statsCb = onStats
        let processedCb = onProcessedFrame
        let frameCb = onFrame
        lock.unlock()

        // Host display — processed RGBA → BGRA pixel buffer for the Flutter texture.
        if let processedCb = processedCb,
           let pb = pixelFactory.makeBGRA(fromRGBA: result.pixels, width: outW, height: outH) {
            processedCb(pb, ptsUs)
        }

        if let s = emitStats { statsCb?(s.0, s.1, s.2, s.3) }

        // Encoder/transport — its own tightly-packed RGBA copy (only the first outW*outH*4 bytes;
        // Downscale may hand back an oversized backing array). Rate-capped.
        if shouldTransmit, let cb = frameCb {
            let need = outW * outH * 4
            let data = result.pixels.withUnsafeBufferPointer { buf -> Data in
                Data(bytes: buf.baseAddress!, count: need)
            }
            cb(data, outW, outH, ptsUs)
        }
    }

    /// Convert a BGRA `CVPixelBuffer` to a tightly-packed RGBA `[UInt8]` (the pipeline works in RGBA).
    /// Handles row padding (`bytesPerRow` may exceed `width*4`).
    private static func bgraToRgba(_ pixelBuffer: CVPixelBuffer) -> [UInt8]? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let w = CVPixelBufferGetWidth(pixelBuffer)
        let h = CVPixelBufferGetHeight(pixelBuffer)
        let srcStride = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let dstStride = w * 4
        var out = [UInt8](repeating: 0, count: dstStride * h)
        let src = base.assumingMemoryBound(to: UInt8.self)
        out.withUnsafeMutableBufferPointer { dbuf in
            guard let dst = dbuf.baseAddress else { return }
            for y in 0..<h {
                let srcRow = src + y * srcStride
                let dstRow = dst + y * dstStride
                var x = 0
                while x < w {
                    let i = x * 4
                    // BGRA -> RGBA: swap B and R, keep G and A.
                    dstRow[i + 0] = srcRow[i + 2]
                    dstRow[i + 1] = srcRow[i + 1]
                    dstRow[i + 2] = srcRow[i + 0]
                    dstRow[i + 3] = srcRow[i + 3]
                    x += 1
                }
            }
        }
        return out
    }
}
