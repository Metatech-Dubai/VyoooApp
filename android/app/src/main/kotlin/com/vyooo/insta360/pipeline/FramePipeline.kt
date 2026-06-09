package com.vyooo.insta360.pipeline

import android.util.Log

/**
 * The capture-side, pre-encoding optimisation pipeline.
 *
 * Runs an ordered list of deterministic [FrameStage]s on each captured frame, upstream of the
 * encoder. A stage may drop a frame (return `null`); the pipeline then stops and reports the drop.
 * If a stage throws, the error is logged and the frame passes through unchanged, so the pipeline
 * never crashes the capture path.
 *
 * Default chain: Downscale → PanoramaDetect → ForwardMask → TemporalDedup. AI hints are supplied via
 * [PipelineHints]; [DeterministicHints] runs the pipeline with no AI.
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

    private companion object {
        const val TAG = "FramePipeline"
    }
}
