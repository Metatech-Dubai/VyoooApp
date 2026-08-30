import Foundation

/// Capture-side spatial reduction (Patent §2) with the AI-assisted decision mapping of Milestone 3.
/// Swift port of Android `DownscaleStage.kt` — the deterministic area-average (box filter), the
/// signal→tier mapping, and the PTS-based dwell hysteresis are reproduced exactly.
///
/// AI influence: the decision layer emits `PipelineHints.perceptualScale` (a bounded metadata signal
/// in [0,1], never a resolution). `tierFor` maps that to one of four 2:1 ERP tiers. With the hint
/// absent (AI off) the stage pins the full tier and passes frames through untouched. No frame is ever
/// dropped. Tier switches are rate-limited by `dwellUs` against the frame PTS.
final class DownscaleStage: FrameStage {

    let name = "Downscale"

    /// Full-resolution tier — the 2K ERP target, and the pinned tier when the AI is disabled.
    var targetWidth: Int
    var targetHeight: Int
    /// Source live-stream resolution, for the source→extract reduction readout.
    var sourceWidth: Int
    var sourceHeight: Int

    init(targetWidth: Int = tierFullW, targetHeight: Int = tierFullH,
         sourceWidth: Int = 2880, sourceHeight: Int = 1440) {
        self.targetWidth = targetWidth
        self.targetHeight = targetHeight
        self.sourceWidth = sourceWidth
        self.sourceHeight = sourceHeight
        self.activeWidth = targetWidth
        self.activeHeight = targetHeight
    }

    /// Master switch for AI-driven tier selection. Off ⇒ pins the full tier (pre-M3 behaviour).
    var adaptiveEnabled = true

    /// A tier must be requested continuously for this long (frame-PTS time) before it is adopted.
    var dwellUs: Int64 = 2_500_000 // 2.5 s

    /// Currently active output tier.
    private(set) var activeWidth: Int
    private(set) var activeHeight: Int

    // ── switch state ──────────────────────────────────────────────────────────────
    private var pendingW = 0
    private var pendingH = 0
    private var pendingSincePtsUs: Int64 = 0
    private var switches: Int64 = 0
    private var lastScale: Float = 1

    // NOTE (Swift vs Android): Android reuses one persistent output buffer. Under Swift copy-on-write
    // that buffer would alias `frame.pixels`, forcing the next in-place stage (ForwardMask) to copy —
    // worse than just allocating. So we allocate the (smaller) reduced-tier buffer fresh per resample
    // and move it into `frame.pixels`, keeping it uniquely referenced. Pixels are identical to Android.

    // Cached column geometry: the source span each output column averages.
    private var colStart = [Int]()
    private var colCount = [Int]()
    private var colCacheInW = 0
    private var colCacheOutW = 0

    /// Source→extract pixel ratio (the SDK's GPU reduction).
    var reductionRatio: Double {
        let src = max(Int64(sourceWidth) * Int64(sourceHeight), 1)
        return Double(Int64(targetWidth) * Int64(targetHeight)) / Double(src)
    }

    /// Extract→active-tier pixel ratio (this stage's own reduction; 1.0 at the full tier).
    var tierRatio: Double {
        let full = max(Int64(targetWidth) * Int64(targetHeight), 1)
        return Double(Int64(activeWidth) * Int64(activeHeight)) / Double(full)
    }

    func process(_ frame: PipelineFrame, hints: PipelineHints) -> PipelineFrame? {
        let scale = hints.perceptualScale
        if !adaptiveEnabled || scale == nil {
            // Deterministic fall-open: pin the full tier. Adopt immediately (no dwell).
            lastScale = 1
            pendingW = 0
            if activeWidth != targetWidth || activeHeight != targetHeight {
                activeWidth = targetWidth
                activeHeight = targetHeight
                switches += 1
            }
            return resampleTo(frame, outW: activeWidth, outH: activeHeight)
        }

        lastScale = scale!
        let (wantW, wantH) = Self.tierFor(scale!)
        applyWithDwell(wantW: wantW, wantH: wantH, ptsUs: frame.ptsUs)
        return resampleTo(frame, outW: activeWidth, outH: activeHeight)
    }

    /// Adopt `wantW`×`wantH` only once it has been requested continuously for `dwellUs`. Restarting
    /// the pending window whenever the request changes gives hysteresis for free.
    private func applyWithDwell(wantW: Int, wantH: Int, ptsUs: Int64) {
        if wantW == activeWidth && wantH == activeHeight {
            pendingW = 0 // already there — cancel any pending change
            return
        }
        if wantW != pendingW || wantH != pendingH {
            pendingW = wantW
            pendingH = wantH
            pendingSincePtsUs = ptsUs
            return
        }
        if ptsUs - pendingSincePtsUs >= dwellUs {
            activeWidth = wantW
            activeHeight = wantH
            pendingW = 0
            switches += 1
        }
    }

    /// Rebuild the per-column source spans; a no-op unless the in/out width pair changed.
    private func ensureColumnTable(inW: Int, outW: Int) {
        if colCacheInW == inW && colCacheOutW == outW { return }
        if colStart.count < outW {
            colStart = [Int](repeating: 0, count: outW)
            colCount = [Int](repeating: 0, count: outW)
        }
        for ox in 0..<outW {
            let s0 = Int(Int64(ox) * Int64(inW) / Int64(outW))
            let s1 = max(s0 + 1, Int(Int64(ox + 1) * Int64(inW) / Int64(outW)))
            colStart[ox] = s0
            colCount[ox] = s1 - s0
        }
        colCacheInW = inW
        colCacheOutW = outW
    }

    /// Deterministic area-average (box filter) to `outW`×`outH`. Returns `frame` untouched when it is
    /// already at the target. Column spans are cached; the channel average uses the exact reciprocal
    /// multiply-shift (`RECIP`) — same math as Android.
    private func resampleTo(_ frame: PipelineFrame, outW: Int, outH: Int) -> PipelineFrame {
        let inW = frame.width
        let inH = frame.height
        if inW == outW && inH == outH { return frame }
        if outW <= 0 || outH <= 0 || inW <= 0 || inH <= 0 { return frame }
        if outW > inW || outH > inH { return frame } // never upscale

        let need = outW * outH * 4
        var dstBuf = [UInt8](repeating: 0, count: need)
        ensureColumnTable(inW: inW, outW: outW)

        let srcStride = inW * 4
        frame.pixels.withUnsafeBufferPointer { sbuf in
            guard let src = sbuf.baseAddress else { return }
            dstBuf.withUnsafeMutableBufferPointer { dbuf in
                guard let dst = dbuf.baseAddress else { return }
                colStart.withUnsafeBufferPointer { csb in
                    colCount.withUnsafeBufferPointer { ccb in
                        let cStart = csb.baseAddress!
                        let cCount = ccb.baseAddress!
                        var di = 0
                        for oy in 0..<outH {
                            let sy0 = Int(Int64(oy) * Int64(inH) / Int64(outH))
                            let sy1 = max(sy0 + 1, Int(Int64(oy + 1) * Int64(inH) / Int64(outH)))
                            let boxH = sy1 - sy0
                            let rowOrigin = sy0 * srcStride
                            for ox in 0..<outW {
                                let boxW = cCount[ox]
                                var rowBase = rowOrigin + cStart[ox] * 4
                                var r = 0, g = 0, b = 0
                                for _ in 0..<boxH {
                                    var si = rowBase
                                    for _ in 0..<boxW {
                                        r += Int(src[si])
                                        g += Int(src[si + 1])
                                        b += Int(src[si + 2])
                                        si += 4
                                    }
                                    rowBase += srcStride
                                }
                                let n = boxW * boxH
                                if n <= Self.maxBox {
                                    let recip = Self.recip[n]
                                    dst[di] = UInt8(truncatingIfNeeded: (r * recip) >> Self.recipShift)
                                    dst[di + 1] = UInt8(truncatingIfNeeded: (g * recip) >> Self.recipShift)
                                    dst[di + 2] = UInt8(truncatingIfNeeded: (b * recip) >> Self.recipShift)
                                } else { // pathological ratio — correctness over speed
                                    dst[di] = UInt8(truncatingIfNeeded: r / n)
                                    dst[di + 1] = UInt8(truncatingIfNeeded: g / n)
                                    dst[di + 2] = UInt8(truncatingIfNeeded: b / n)
                                }
                                dst[di + 3] = 255
                                di += 4
                            }
                        }
                    }
                }
            }
        }

        frame.pixels = dstBuf
        frame.width = outW
        frame.height = outH
        return frame
    }

    /// KPI readout for `getPipelineMetrics()`.
    func stats() -> [String: Any] {
        [
            "spatialAdaptive": adaptiveEnabled,
            "spatialWidth": activeWidth,
            "spatialHeight": activeHeight,
            "spatialTierRatio": tierRatio,
            "spatialSourceRatio": reductionRatio,
            "spatialSwitches": switches,
            "spatialLastScale": lastScale,
        ]
    }

    /// Reset to the full tier (used on stream restart so a new session starts unreduced).
    func reset() {
        activeWidth = targetWidth
        activeHeight = targetHeight
        pendingW = 0
        pendingSincePtsUs = 0
        switches = 0
        lastScale = 1
    }

    // MARK: - Constants (mirrored exactly from Android)

    /// Reciprocal multiply-shift replacing per-pixel division: `sum / n` → `(sum * recip[n]) >> shift`.
    /// Shift 21 is the smallest exact value for every `n` in `1..maxBox` across the accumulator range.
    private static let recipShift = 21
    private static let maxBox = 64
    private static let recip: [Int] = (0...maxBox).map { n in n == 0 ? 0 : (1 << recipShift) / n + 1 }

    // Tiers are all exactly 2:1 (ERP) and divisible by 16 (encoder macroblock friendly).
    static let tierFullW = 1920
    static let tierFullH = 960
    static let tierHighW = 1600
    static let tierHighH = 800
    static let tierMidW = 1280
    static let tierMidH = 640
    static let tierLowW = 960
    static let tierLowH = 480

    /// Deterministic signal→tier mapping. Pure and side-effect free.
    static func tierFor(_ scale: Float) -> (Int, Int) {
        if scale >= 0.85 { return (tierFullW, tierFullH) }
        if scale >= 0.65 { return (tierHighW, tierHighH) }
        if scale >= 0.45 { return (tierMidW, tierMidH) }
        return (tierLowW, tierLowH)
    }
}
