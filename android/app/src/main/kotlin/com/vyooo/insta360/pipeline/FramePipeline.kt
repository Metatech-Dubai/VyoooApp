package com.vyooo.insta360.pipeline

import android.util.Log

/**
 * The capture-side pre-encoding optimisation pipeline (Patent 1, Figs 1–3).
 *
 * Runs an ordered list of deterministic [FrameStage]s on each captured frame, upstream of the
 * encoder. A stage may drop a frame (return `null`); the pipeline then stops and reports the drop.
 * **Fall-open discipline:** if a stage throws, the error is logged and the frame passes through
 * unchanged — the pipeline never crashes the capture path (Patent: must remain functional without AI
 * and under real-time constraints).
 *
 * Milestone 1 chain: Downscale → PanoramaDetect → ForwardMask → (TemporalDedup placeholder).
 * AI hints are supplied via [PipelineHints]; M1 uses [DeterministicHints] (no AI).
 */
class FramePipeline(
    private val stages: List<FrameStage>,
    private val hints: PipelineHints = DeterministicHints,
) {
    val metrics = PipelineMetrics()

    /** Returns the processed frame, or `null` if a stage dropped it. */
    fun process(frame: PipelineFrame): PipelineFrame? {
        val inW = frame.width
        val inH = frame.height
        val t0 = System.nanoTime()
        var current: PipelineFrame = frame
        for (stage in stages) {
            val s0 = System.nanoTime()
            val result = try {
                stage.process(current, hints)
            } catch (t: Throwable) {
                Log.e(TAG, "stage '${stage.name}' failed; falling open (pass-through)", t)
                current // fall open
            }
            metrics.recordStage(stage.name, System.nanoTime() - s0)
            if (result == null) {
                metrics.recordDropped()
                return null
            }
            current = result
        }
        metrics.recordFrame(inW, inH, current.width, current.height, System.nanoTime() - t0)
        return current
    }

    companion object {
        private const val TAG = "FramePipeline"

        /** The Milestone-1 default chain (no AI; temporal-dedup is a no-op placeholder for M2). */
        fun defaultM1(hints: PipelineHints = DeterministicHints): FramePipeline = FramePipeline(
            listOf(
                DownscaleStage(),
                PanoramaDetectStage(),
                ForwardMaskStage(),
                TemporalDedupStage(),
            ),
            hints,
        )
    }
}
