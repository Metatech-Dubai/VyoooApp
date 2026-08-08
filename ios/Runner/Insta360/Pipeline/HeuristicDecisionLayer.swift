import Foundation

/// Milestone 3 — bounded, on-device, heuristic AI-assisted decision layer. Swift port of Android
/// `HeuristicDecisionLayer.kt` (every constant and rule mirrored exactly).
///
/// Observes low-cost scene statistics from a coarse luma grid and writes decision signals only into
/// the shared `MutableHints` the deterministic pipeline consumes. It never modifies pixel content and
/// the pipeline runs unchanged when disabled (deterministic fall-open).
///
/// Emits: `motion` (hysteretic moving/static decision → `TemporalDedupStage`), `perceptualScale`
/// (scene-complexity → `DownscaleStage`, applied when `applyPerceptual`), `forwardThetaDeg`
/// (salience-centroid orientation, applied when `applyOrientation`).
final class HeuristicDecisionLayer {

    private let hints: MutableHints

    init(hints: MutableHints) { self.hints = hints }

    /// Master enable. On → supplies the decision signals the pipeline acts on.
    var enabled = true
    /// Emit the computed spatial-reduction recommendation as a live hint (M3 spatial influence).
    var applyPerceptual = true
    /// Apply the computed forward orientation to the hint (default off = mapping only).
    var applyOrientation = false
    /// Observe every Nth frame (≥1).
    var cadence = 1

    // ── Motion decision tuning ───────────────────────────────────────────────
    var motionEnter: Float = 0.030
    var motionExit: Float = 0.015
    var motionHoldMs: Int64 = 400
    var refLagMs: Int64 = 250

    // ── Runtime state (extract thread) ───────────────────────────────────────
    private var history: [(UInt64, [Int])] = []
    private var frameCounter: Int64 = 0
    private var activityEma: Float = 0
    private var detailEma: Float = 0
    private var thetaEma: Float = 0
    private var moving = false
    private var belowExitSinceNs: UInt64 = 0

    // ── Exposed signals + performance metrics ────────────────────────────────
    private var lastActivity: Float = 0
    private var lastMoving = false
    private var lastPerceptualScale: Float = 1
    private var lastRecommendedScale: Float = 1
    private var lastThetaDeg: Float = 0
    private var lastDetail: Float = 0
    private var decisions: Int64 = 0
    private var motionSpans: Int64 = 0
    private var overheadMsEma: Double = 0

    /// Observe one frame's luma and update the decision signals.
    func observe(_ pixels: [UInt8], width: Int, height: Int) {
        if !enabled {
            clearHints()
            return
        }
        frameCounter += 1
        let n = max(cadence, 1)
        // Between observations the previous decision stands (the hint is sticky).
        if frameCounter % Int64(n) != 0 { return }

        let t0 = DispatchTime.now().uptimeNanoseconds
        guard let grid = sampleLuma(pixels, width, height) else { return }

        // Activity vs a FIXED ~refLagMs time-lagged reference — never a state-dependent one.
        history.append((t0, grid))
        let lagNs = UInt64(refLagMs) * 1_000_000
        while history.count > 1 && t0 - history[0].0 > lagNs { history.removeFirst() }
        let ref = history.count > 1 ? history[0].1 : nil
        let activity = ref == nil ? Float(1) : topPercentileDiff(grid, ref!)
        activityEma = Self.motionEmaAlpha * activity + (1 - Self.motionEmaAlpha) * activityEma

        // Hysteretic moving/static decision + hold.
        if moving {
            if activityEma < motionExit {
                if belowExitSinceNs == 0 { belowExitSinceNs = t0 }
                if Int64((t0 - belowExitSinceNs) / 1_000_000) >= motionHoldMs {
                    moving = false
                    belowExitSinceNs = 0
                    NSLog("[HeuristicAI] gate moving->STATIC activity=\(activityEma) exit=\(motionExit) hold=\(motionHoldMs)ms")
                }
            } else {
                belowExitSinceNs = 0 // re-armed by fresh activity
            }
        } else if activityEma >= motionEnter {
            moving = true
            belowExitSinceNs = 0
            motionSpans += 1
            NSLog("[HeuristicAI] gate static->MOVING activity=\(activityEma) enter=\(motionEnter) spans=\(motionSpans)")
        }

        // Spatial detail: mean neighbour gradient of the grid.
        let detail = neighbourGradient(grid)
        detailEma = Self.detailEmaAlpha * detail + (1 - Self.detailEmaAlpha) * detailEma

        // Perceptual score in [0,1] (1 = keep full resolution).
        let perceptual = min(max(0.5 + 2.0 * detailEma + 0.5 * activityEma, 0), 1)
        // Recommended reduction factor of the 2K target (never below RECOMMEND_FLOOR).
        let recommended = min(max(Self.recommendFloor + (1 - Self.recommendFloor) * perceptual,
                                  Self.recommendFloor), 1)

        // Forward orientation: salience-weighted centroid column → θ in degrees, heavily smoothed.
        let theta = salienceCentroidDeg(grid)
        thetaEma = Self.thetaEmaAlpha * theta + (1 - Self.thetaEmaAlpha) * thetaEma

        // Write decision signals (metadata only). `motion` is a DECISION (moving/static), not a score.
        hints.motion = moving ? Self.signalMoving : Self.signalStatic
        hints.perceptualScale = applyPerceptual ? perceptual : nil
        hints.forwardThetaDeg = applyOrientation ? thetaEma : nil
        // isPanoramic left to the deterministic detector.

        lastActivity = activityEma
        lastMoving = moving
        lastPerceptualScale = perceptual
        lastRecommendedScale = recommended
        lastThetaDeg = thetaEma
        lastDetail = detailEma
        decisions += 1
        let ms = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000.0
        overheadMsEma = decisions == 1 ? ms : 0.1 * ms + 0.9 * overheadMsEma
    }

    /// Performance-observation + influence-mapping metrics (M3 deliverable #4).
    func stats() -> [String: Any] {
        [
            "aiEnabled": enabled,
            "aiApplyPerceptual": applyPerceptual,
            "aiApplyOrientation": applyOrientation,
            "aiDecisions": decisions,
            "aiOverheadMs": overheadMsEma,
            "aiMoving": lastMoving,
            "aiActivity": lastActivity,
            "aiMotionSpans": motionSpans,
            "aiSpatialDetail": lastDetail,
            "aiPerceptualScale": lastPerceptualScale,
            "aiRecommendedScale": lastRecommendedScale,
            "aiThetaDeg": lastThetaDeg,
        ]
    }

    func reset() {
        history.removeAll()
        frameCounter = 0
        activityEma = 0; detailEma = 0; thetaEma = 0
        moving = false; belowExitSinceNs = 0
        lastActivity = 0; lastMoving = false
        lastPerceptualScale = 1; lastRecommendedScale = 1; lastThetaDeg = 0; lastDetail = 0
        decisions = 0; motionSpans = 0; overheadMsEma = 0
        clearHints()
    }

    private func clearHints() {
        hints.motion = nil
        hints.perceptualScale = nil
        hints.forwardThetaDeg = nil
    }

    // ── Heuristics ───────────────────────────────────────────────────────────

    /// Mean of the top `TOP_FRACTION` cell differences, normalised to [0,1] — localized-motion aware.
    private func topPercentileDiff(_ cur: [Int], _ prev: [Int]) -> Float {
        if cur.count != prev.count || cur.isEmpty { return 1 }
        var diffs = [Int](repeating: 0, count: cur.count)
        for i in cur.indices { diffs[i] = abs(cur[i] - prev[i]) }
        diffs.sort() // ascending
        let k = max(Int(Float(cur.count) * Self.topFraction), 1)
        var acc: Int64 = 0
        for i in (cur.count - k)..<cur.count { acc += Int64(diffs[i]) }
        return Float(min(max(Double(acc) / (Double(k) * 255.0), 0), 1))
    }

    /// Mean absolute right/below neighbour gradient of the grid, normalised to [0,1].
    private func neighbourGradient(_ grid: [Int]) -> Float {
        var acc: Int64 = 0
        var count = 0
        for r in 0..<Self.gridRows {
            for c in 0..<Self.gridCols {
                let v = grid[r * Self.gridCols + c]
                if c + 1 < Self.gridCols { acc += Int64(abs(v - grid[r * Self.gridCols + c + 1])); count += 1 }
                if r + 1 < Self.gridRows { acc += Int64(abs(v - grid[(r + 1) * Self.gridCols + c])); count += 1 }
            }
        }
        if count == 0 { return 0 }
        return Float(min(max(Double(acc) / (Double(count) * 255.0), 0), 1))
    }

    /// Salience-weighted centroid column → θ in degrees ([-180,180], 0 = ERP centre / forward).
    private func salienceCentroidDeg(_ grid: [Int]) -> Float {
        var wsum = 0.0
        var vsum = 0.0
        for c in 0..<Self.gridCols {
            var colSal: Int64 = 0
            for r in 0..<Self.gridRows { colSal += Int64(grid[r * Self.gridCols + c]) }
            wsum += Double(c) * Double(colSal)
            vsum += Double(colSal)
        }
        if vsum <= 0 { return 0 }
        let centroidCol = wsum / vsum
        return Float(((centroidCol / Double(Self.gridCols)) - 0.5) * 360.0)
    }

    /// Coarse luma grid (centre pixel per cell). Nil if the frame buffer is unusable.
    private func sampleLuma(_ px: [UInt8], _ w: Int, _ h: Int) -> [Int]? {
        if w <= 0 || h <= 0 || px.count < w * h * 4 { return nil }
        var out = [Int](repeating: 0, count: Self.gridCols * Self.gridRows)
        px.withUnsafeBufferPointer { buf in
            guard let p = buf.baseAddress else { return }
            var k = 0
            for ry in 0..<Self.gridRows {
                let y = min(max(Int((Float(ry) + 0.5) * Float(h) / Float(Self.gridRows)), 0), h - 1)
                let rowBase = y * w
                for cx in 0..<Self.gridCols {
                    let x = min(max(Int((Float(cx) + 0.5) * Float(w) / Float(Self.gridCols)), 0), w - 1)
                    let idx = (rowBase + x) * 4
                    let r = Int(p[idx]); let g = Int(p[idx + 1]); let b = Int(p[idx + 2])
                    out[k] = (r * 77 + g * 150 + b * 29) >> 8 // BT.601 luma
                    k += 1
                }
            }
        }
        return out
    }

    // MARK: - Constants (mirrored exactly from Android)
    private static let gridCols = 32
    private static let gridRows = 18
    private static let topFraction: Float = 0.15
    private static let motionEmaAlpha: Float = 0.4
    private static let detailEmaAlpha: Float = 0.2
    private static let thetaEmaAlpha: Float = 0.05
    private static let recommendFloor: Float = 0.5
    private static let signalMoving: Float = 1.0
    private static let signalStatic: Float = 0.0
}
