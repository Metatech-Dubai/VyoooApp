import Foundation

/// Runtime metrics for the pipeline: per-stage latency, throughput, and the spatial-reduction ratio.
/// Swift port of Android `PipelineMetrics.kt` (all `@Synchronized` methods mapped to an `NSLock`).
///
/// Recorded on the SDK extract thread inside `FramePipeline.process`; `snapshot()` may be read from
/// another thread (the platform channel). Emits the identical keys Android does:
/// `fps, framesIn, framesOut, framesDropped, totalMs, spatialReduction, stagesMs`.
final class PipelineMetrics {

    private let lock = NSLock()

    // Insertion-ordered per-stage EMA latency (ms). A plain dictionary loses order, so we keep the
    // key order alongside it to match Android's LinkedHashMap output.
    private var stageEmaMs: [String: Double] = [:]
    private var stageOrder: [String] = []

    private var framesIn: Int64 = 0
    private var framesOut: Int64 = 0
    private var framesDropped: Int64 = 0
    private var lastReduction: Double = 1.0 // out px / in px
    private var lastTotalMs: Double = 0.0

    // fps over a 1-second sliding window
    private var windowStartNs: UInt64 = 0
    private var framesThisWindow: Int = 0
    private var lastFps: Int = 0

    private let emaAlpha = 0.1

    func recordStage(_ name: String, nanos: UInt64) {
        lock.lock(); defer { lock.unlock() }
        let ms = Double(nanos) / 1_000_000.0
        if let prev = stageEmaMs[name] {
            stageEmaMs[name] = prev + emaAlpha * (ms - prev)
        } else {
            stageEmaMs[name] = ms
            stageOrder.append(name)
        }
    }

    func recordFrame(inW: Int, inH: Int, outW: Int, outH: Int, totalNanos: UInt64) {
        lock.lock(); defer { lock.unlock() }
        framesIn += 1
        framesOut += 1
        let inPx = max(Int64(inW) * Int64(inH), 1)
        lastReduction = Double(Int64(outW) * Int64(outH)) / Double(inPx)
        lastTotalMs = Double(totalNanos) / 1_000_000.0

        let now = DispatchTime.now().uptimeNanoseconds
        if windowStartNs == 0 { windowStartNs = now }
        framesThisWindow += 1
        if now - windowStartNs >= 1_000_000_000 {
            lastFps = framesThisWindow
            framesThisWindow = 0
            windowStartNs = now
        }
    }

    func recordDropped() {
        lock.lock(); defer { lock.unlock() }
        framesIn += 1
        framesDropped += 1
    }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        stageEmaMs.removeAll()
        stageOrder.removeAll()
        framesIn = 0; framesOut = 0; framesDropped = 0
        lastReduction = 1.0; lastTotalMs = 0.0
        windowStartNs = 0; framesThisWindow = 0; lastFps = 0
    }

    /// Map form for the method channel (all values are channel-codec friendly).
    func snapshot() -> [String: Any] {
        lock.lock(); defer { lock.unlock() }
        var stages: [String: Any] = [:]
        for k in stageOrder { stages[k] = stageEmaMs[k] }
        return [
            "fps": lastFps,
            "framesIn": framesIn,
            "framesOut": framesOut,
            "framesDropped": framesDropped,
            "totalMs": lastTotalMs,
            "spatialReduction": lastReduction, // out px / in px (lower = more reduction)
            "stagesMs": stages,
        ]
    }
}
