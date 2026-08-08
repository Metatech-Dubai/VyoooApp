import Foundation

/// Temporal redundancy reduction — motion/static time-paced variant. Swift port of Android
/// `TemporalDedupStage.kt`.
///
/// Keeps the live stream at full/original fps while there is motion, and drops to an evenly-spaced
/// `staticFps` (default 10) while the scene is static. Pacing is time-based (`PipelineFrame.ptsUs`)
/// so kept static frames are evenly spaced.
///
/// Decision per frame:
///  - motion (luma change ≥ `motionThreshold`) → keep (full rate).
///  - static → keep only if ≥ `1/staticFps` s since the last kept frame; else drop (`nil`).
///
/// PTS is never modified/reordered.
final class TemporalDedupStage: FrameStage {

    let name = "TemporalDedup"

    /// Normalised luma MAD (0..1) at/above which a frame counts as motion → kept at full rate.
    var motionThreshold: Float
    /// Frames/sec transmitted while static — evenly time-paced so the output stays smooth.
    var staticFps: Int

    /// Live A/B toggle. When false every frame passes through (no reduction).
    var enabled = true

    init(motionThreshold: Float = 0.010, staticFps: Int = 10) {
        self.motionThreshold = motionThreshold
        self.staticFps = staticFps
    }

    // ── Runtime state (extract thread only) ──────────────────────────────────
    private var lastKeptPtsUs = Int64.min
    private var lastGrid: [Int]?
    private var lastMotion: Float = 0

    // ── Cumulative stats (KPI readout) ───────────────────────────────────────
    private var seen: Int64 = 0
    private var kept: Int64 = 0
    private var motionKeeps: Int64 = 0
    private var staticKeeps: Int64 = 0
    private var staticDrops: Int64 = 0

    func process(_ frame: PipelineFrame, hints: PipelineHints) -> PipelineFrame? {
        if !enabled {
            resetRuntimeState()
            return frame
        }

        seen += 1
        let curGrid = sampleGrid(frame)
        let motion = hints.motion ?? motionFrom(curGrid)
        lastMotion = motion

        let moving = motion >= motionThreshold
        let minGapUs = Int64(1_000_000 / max(staticFps, 1))
        let elapsedUs = lastKeptPtsUs == Int64.min ? Int64.max : frame.ptsUs - lastKeptPtsUs
        // Keep every motion frame (full rate); in a static scene keep one frame per staticFps window.
        let keep = moving || elapsedUs >= minGapUs

        if keep {
            lastKeptPtsUs = frame.ptsUs
            if let g = curGrid { lastGrid = g }
            kept += 1
            if moving { motionKeeps += 1 } else { staticKeeps += 1 }
            return frame
        } else {
            staticDrops += 1
            return nil
        }
    }

    /// Live KPI snapshot: keep ratio, motion vs. static-paced keeps, static drops.
    func stats() -> [String: Any] {
        [
            "temporalEnabled": enabled,
            "staticFps": staticFps,
            "framesSeen": seen,
            "framesKept": kept,
            "keepRatio": seen > 0 ? Double(kept) / Double(seen) : 1.0,
            "motionKeeps": motionKeeps,
            "staticKeeps": staticKeeps,
            "staticDrops": staticDrops,
            "lastMotion": lastMotion,
        ]
    }

    /// Clear runtime state + cumulative stats.
    func reset() {
        resetRuntimeState()
        seen = 0; kept = 0; motionKeeps = 0; staticKeeps = 0; staticDrops = 0
        lastMotion = 0
    }

    private func resetRuntimeState() {
        lastKeptPtsUs = Int64.min
        lastGrid = nil
    }

    /// Normalised (0..1) luma MAD of `cur` vs. the last kept grid; 1 (max, keep) if no baseline.
    private func motionFrom(_ cur: [Int]?) -> Float {
        guard let cur = cur else { return 1 }
        guard let prev = lastGrid else { return 1 }
        if prev.count != cur.count { return 1 }
        var acc: Int64 = 0
        for i in cur.indices { acc += Int64(abs(cur[i] - prev[i])) }
        return Float(min(max(Double(acc) / (Double(cur.count) * 255.0), 0), 1))
    }

    /// Sample a coarse luma grid (centre pixel per cell). Nil if the frame buffer is unusable.
    private func sampleGrid(_ frame: PipelineFrame) -> [Int]? {
        let w = frame.width
        let h = frame.height
        if w <= 0 || h <= 0 { return nil }
        if frame.pixels.count < w * h * 4 { return nil }

        var out = [Int](repeating: 0, count: Self.gridCols * Self.gridRows)
        frame.pixels.withUnsafeBufferPointer { buf in
            guard let px = buf.baseAddress else { return }
            var k = 0
            for ry in 0..<Self.gridRows {
                let y = min(max(Int((Float(ry) + 0.5) * Float(h) / Float(Self.gridRows)), 0), h - 1)
                let rowBase = y * w
                for cx in 0..<Self.gridCols {
                    let x = min(max(Int((Float(cx) + 0.5) * Float(w) / Float(Self.gridCols)), 0), w - 1)
                    let idx = (rowBase + x) * 4
                    let r = Int(px[idx])
                    let g = Int(px[idx + 1])
                    let b = Int(px[idx + 2])
                    // BT.601 luma (integer approx): 0.299R + 0.587G + 0.114B.
                    out[k] = (r * 77 + g * 150 + b * 29) >> 8
                    k += 1
                }
            }
        }
        return out
    }

    private static let gridCols = 32
    private static let gridRows = 18
}
