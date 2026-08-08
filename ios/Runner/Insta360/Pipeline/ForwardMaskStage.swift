import Foundation

/// Forward-only panoramic retention. Swift port of Android `ForwardMaskStage.kt`.
///
/// Keeps a forward angular field of view `forwardFovDeg` (≈180–220°, default 200°) of the
/// equirectangular frame and suppresses the rear to opaque black, with an optional feathered boundary
/// `featherDeg`.
///
/// ERP geometry: horizontal axis is longitude θ ∈ [−180°, +180°] mapped linearly to columns
/// x ∈ [0, W). Forward direction θ₀ (default 0) is the centre column; the rear (±180°) is at the
/// left/right edges. Forward retention keeps a centred horizontal band of width `(F/360)·W` and
/// blacks out the two edge bands. Per-column suppression factors are precomputed and cached.
final class ForwardMaskStage: FrameStage {

    let name = "ForwardMask"

    var forwardFovDeg: Float
    var featherDeg: Float

    /// Live toggle for the masked/unmasked view: when false the full 360° frame passes through.
    var enabled = true

    init(forwardFovDeg: Float = 200, featherDeg: Float = 6) {
        self.forwardFovDeg = forwardFovDeg
        self.featherDeg = featherDeg
    }

    /// Fraction of the horizontal field retained (e.g. 200/360 ≈ 0.56). For reporting.
    var retainedFraction: Float {
        min(max(forwardFovDeg / 360, 0), 1)
    }

    // Cached per-column factor table (1.0 keep … 0.0 suppress, with feather ramp).
    private var cachedFactors: [Float]?
    private var cachedWidth = -1
    private var cachedFov: Float = -1
    private var cachedFeather: Float = -1
    private var cachedTheta = Float.nan

    func process(_ frame: PipelineFrame, hints: PipelineHints) -> PipelineFrame? {
        if !enabled { return frame } // unmasked view (full 360°)
        // Planar bypass: never mask non-panoramic input.
        if frame.meta.isPanoramic == false { return frame }

        let keepFrac = retainedFraction
        if keepFrac >= 1 { return frame } // full 360° retained → nothing to suppress

        let w = frame.width
        let h = frame.height
        if w <= 0 || h <= 0 { return frame }
        if frame.pixels.count < w * h * 4 { return frame }

        let theta0 = hints.forwardThetaDeg ?? frame.meta.forwardThetaDeg
        let factors = factorTable(width: w, keepFrac: keepFrac, theta0: theta0)

        let stride = w * 4
        frame.pixels.withUnsafeMutableBufferPointer { buf in
            guard let px = buf.baseAddress else { return }
            factors.withUnsafeBufferPointer { fb in
                guard let f = fb.baseAddress else { return }
                var rowBase = 0
                for _ in 0..<h {
                    var i = rowBase
                    for x in 0..<w {
                        let fx = f[x]
                        if fx >= 1 {
                            // kept — leave pixel untouched
                        } else if fx <= 0 {
                            // suppressed → opaque black
                            px[i] = 0; px[i + 1] = 0; px[i + 2] = 0; px[i + 3] = 255
                        } else {
                            // feather ramp toward black; alpha kept opaque
                            px[i] = UInt8(truncatingIfNeeded: Int(Float(px[i]) * fx))
                            px[i + 1] = UInt8(truncatingIfNeeded: Int(Float(px[i + 1]) * fx))
                            px[i + 2] = UInt8(truncatingIfNeeded: Int(Float(px[i + 2]) * fx))
                            px[i + 3] = 255
                        }
                        i += 4
                    }
                    rowBase += stride
                }
            }
        }
        return frame
    }

    /// Per-column keep factor in [0,1], centred on θ₀, with a feather ramp at the kept-region edges.
    private func factorTable(width: Int, keepFrac: Float, theta0: Float) -> [Float] {
        if let cached = cachedFactors, cachedWidth == width, cachedFov == forwardFovDeg,
           cachedFeather == featherDeg, cachedTheta == theta0 {
            return cached
        }

        var factors = [Float](repeating: 0, count: width)
        let centerX = Float(width) / 2 + (theta0 / 360) * Float(width)
        let halfKeep = keepFrac * Float(width) / 2
        let left = centerX - halfKeep
        let right = centerX + halfKeep
        let featherPx = max(featherDeg / 360 * Float(width), 0)

        for x in 0..<width {
            let xc = Float(x) + 0.5
            if xc < left || xc > right {
                factors[x] = 0
            } else if featherPx <= 0 {
                factors[x] = 1
            } else {
                let dEdge = min(xc - left, right - xc) // distance into kept region
                factors[x] = min(max(dEdge / featherPx, 0), 1)
            }
        }

        cachedFactors = factors
        cachedWidth = width
        cachedFov = forwardFovDeg
        cachedFeather = featherDeg
        cachedTheta = theta0
        return factors
    }
}
