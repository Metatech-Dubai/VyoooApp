import Foundation
import CoreVideo

/// The single insertion point + fan-out hub for extracted Insta360 flat-pano (ERP) frames.
/// iOS mirror of the Android `Insta360FrameSink` object.
///
/// The camera preview stream is stitched to an equirectangular BGRA `CVPixelBuffer` by the SDK's
/// `INSCameraFlatPanoOutput` (see `Insta360PreviewView`). Each frame is submitted here, then fanned
/// out to:
///   - `onFrame`          — RGBA bytes for the encoder / transport (Agora), only when `streamingEnabled`.
///   - `onProcessedFrame` — the latest BGRA `CVPixelBuffer` for the host Flutter `Texture` (see
///                          `Insta360ProcessedTexture` created via `createProcessedTexture`).
///   - `onStats`          — (w, h, fps, totalCount) ~1×/sec.
///
/// NOTE ON THE OPTIMISATION PIPELINE
/// The Android build runs the extracted frame through a capture-side pipeline
/// (`com/vyooo/insta360/pipeline/*`: Downscale → PanoramaDetect → ForwardMask → TemporalDedup, fed
/// by a heuristic AI decision layer). That pipeline is NOT yet ported to iOS — the toggle methods
/// (`setMaskEnabled` / `setTemporalEnabled` / `setAiEnabled`) store their state here so the Dart API
/// is complete and non-crashing, but the frame is currently forwarded **pass-through** (full-res
/// ERP). Porting the pipeline (ideally via Accelerate/vImage or Metal) is a follow-up — see the
/// integration guide's "Gaps / Risks".
final class Insta360FrameSink {

    static let shared = Insta360FrameSink()
    private init() {}

    private let lock = NSLock()

    // ── Fan-out sinks (set by the bridge / texture) ─────────────────────────────
    /// RGBA (w*h*4) for the encoder/transport. Only invoked while `streamingEnabled`.
    var onFrame: ((Data, Int, Int, Int64) -> Void)?
    /// Latest BGRA pixel buffer for the host texture. Receives the retained buffer (read it now).
    var onProcessedFrame: ((CVPixelBuffer, Int64) -> Void)?
    /// (width, height, fps, totalCount) — emitted ~1×/sec.
    var onStats: ((Int, Int, Int, Int64) -> Void)?

    var streamingEnabled = false

    // ── Optimisation-pipeline toggles (state only until the pipeline is ported) ──
    private(set) var maskEnabled = true
    private(set) var temporalEnabled = true
    private(set) var aiEnabled = true
    func setMaskEnabled(_ v: Bool) { maskEnabled = v }
    func setTemporalEnabled(_ v: Bool) { temporalEnabled = v }
    func setAiEnabled(_ v: Bool) { aiEnabled = v }

    // ── Stats ───────────────────────────────────────────────────────────────────
    private var count: Int64 = 0
    private var windowStartNs: UInt64 = 0
    private var framesThisWindow = 0
    private var lastFps = 0
    private var baseTimestamp: TimeInterval = 0
    private var lastTransmitNs: UInt64 = 0

    /// Cap the transmit copy rate (mirrors Android's 24 fps ceiling). Each transmitted frame is a
    /// fresh ~7 MB RGBA copy + another in the platform-channel codec.
    private let transmitMinIntervalNs: UInt64 = 1_000_000_000 / 24

    func reset() {
        lock.lock(); defer { lock.unlock() }
        count = 0; windowStartNs = 0; framesThisWindow = 0; lastFps = 0
        baseTimestamp = 0; lastTransmitNs = 0
    }

    func metrics() -> [String: Any] {
        lock.lock(); defer { lock.unlock() }
        return [
            "fps": lastFps,
            "framesOut": count,
            "streaming": streamingEnabled,
            "maskEnabled": maskEnabled,
            "temporalEnabled": temporalEnabled,
            "aiEnabled": aiEnabled,
            // Honest signal to the UI: the Android reduction pipeline is not yet running on iOS.
            "pipelinePort": "pending",
        ]
    }

    /// Submit one stitched ERP frame. `pixelBuffer` is BGRA (`kCVPixelFormatType_32BGRA`).
    /// `timestamp` is the SDK video-frame timestamp (seconds).
    func submit(pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) {
        let w = CVPixelBufferGetWidth(pixelBuffer)
        let h = CVPixelBufferGetHeight(pixelBuffer)
        guard w > 0, h > 0 else { return }

        let now = DispatchTime.now().uptimeNanoseconds

        lock.lock()
        if baseTimestamp == 0 { baseTimestamp = timestamp }
        let ptsUs = Int64((timestamp - baseTimestamp) * 1_000_000)
        count += 1
        if windowStartNs == 0 { windowStartNs = now }
        framesThisWindow += 1
        var emitStats: (Int, Int, Int, Int64)?
        if now - windowStartNs >= 1_000_000_000 {
            lastFps = framesThisWindow
            framesThisWindow = 0
            windowStartNs = now
            emitStats = (w, h, lastFps, count)
        }
        let streaming = streamingEnabled
        let shouldTransmit = streaming && (now - lastTransmitNs >= transmitMinIntervalNs)
        if shouldTransmit { lastTransmitNs = now }
        let statsCb = onStats
        let processedCb = onProcessedFrame
        let frameCb = onFrame
        lock.unlock()

        // Host texture — hand over the (retained) BGRA buffer directly; no copy.
        processedCb?(pixelBuffer, ptsUs)

        if let s = emitStats { statsCb?(s.0, s.1, s.2, s.3) }

        // Encoder/transport — its own RGBA copy so the consumer may retain it. Rate-capped.
        if shouldTransmit, let cb = frameCb {
            if let rgba = Self.bgraToRgba(pixelBuffer) {
                cb(rgba, w, h, ptsUs)
            }
        }
    }

    /// Convert a BGRA `CVPixelBuffer` to a tightly-packed RGBA `Data` (Flutter/Agora expect RGBA).
    /// Handles row padding (`bytesPerRow` may exceed `width*4`).
    private static func bgraToRgba(_ pixelBuffer: CVPixelBuffer) -> Data? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let w = CVPixelBufferGetWidth(pixelBuffer)
        let h = CVPixelBufferGetHeight(pixelBuffer)
        let srcStride = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let dstStride = w * 4
        var out = Data(count: dstStride * h)
        out.withUnsafeMutableBytes { (dstRaw: UnsafeMutableRawBufferPointer) in
            guard let dst = dstRaw.baseAddress else { return }
            let src = base.assumingMemoryBound(to: UInt8.self)
            let dstB = dst.assumingMemoryBound(to: UInt8.self)
            for y in 0..<h {
                let srcRow = src + y * srcStride
                let dstRow = dstB + y * dstStride
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
