package com.vyooo.insta360.pipeline

/**
 * Real-time validation metrics for the pipeline (Milestone 1 deliverable: "real-time validation").
 *
 * Captures per-stage latency, throughput, and the spatial-reduction ratio. Recorded on the SDK
 * extract thread inside [FramePipeline.process]; [snapshot] may be read from another thread.
 * Bitrate-reduction (the encoder-side KPI) is measured separately via Agora `localVideoStats`.
 */
class PipelineMetrics {

    private val stageEmaMs = LinkedHashMap<String, Double>()
    @Volatile private var framesIn: Long = 0
    @Volatile private var framesOut: Long = 0
    @Volatile private var framesDropped: Long = 0
    @Volatile private var lastReduction: Double = 1.0 // out px / in px
    @Volatile private var lastTotalMs: Double = 0.0

    // fps over a 1-second sliding window
    private var windowStartNs: Long = 0
    private var framesThisWindow: Int = 0
    @Volatile private var lastFps: Int = 0

    private val emaAlpha = 0.1

    @Synchronized
    fun recordStage(name: String, nanos: Long) {
        val ms = nanos / 1_000_000.0
        val prev = stageEmaMs[name]
        stageEmaMs[name] = if (prev == null) ms else prev + emaAlpha * (ms - prev)
    }

    @Synchronized
    fun recordFrame(inW: Int, inH: Int, outW: Int, outH: Int, totalNanos: Long) {
        framesIn++
        framesOut++
        val inPx = (inW.toLong() * inH).coerceAtLeast(1)
        lastReduction = (outW.toLong() * outH).toDouble() / inPx
        lastTotalMs = totalNanos / 1_000_000.0

        val now = System.nanoTime()
        if (windowStartNs == 0L) windowStartNs = now
        framesThisWindow++
        if (now - windowStartNs >= 1_000_000_000L) {
            lastFps = framesThisWindow
            framesThisWindow = 0
            windowStartNs = now
        }
    }

    @Synchronized
    fun recordDropped() {
        framesIn++
        framesDropped++
    }

    @Synchronized
    fun reset() {
        stageEmaMs.clear()
        framesIn = 0; framesOut = 0; framesDropped = 0
        lastReduction = 1.0; lastTotalMs = 0.0
        windowStartNs = 0; framesThisWindow = 0; lastFps = 0
    }

    /** Map form for the method/event channel (all values are channel-codec friendly). */
    @Synchronized
    fun snapshot(): Map<String, Any> = mapOf(
        "fps" to lastFps,
        "framesIn" to framesIn,
        "framesOut" to framesOut,
        "framesDropped" to framesDropped,
        "totalMs" to lastTotalMs,
        "spatialReduction" to lastReduction, // out px / in px (lower = more reduction)
        "stagesMs" to HashMap(stageEmaMs),
    )
}
