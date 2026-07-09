package com.vyooo.insta360

import com.arashivision.graphicpath.insmedia.common.MediaFrame

/**
 * Converts the SDK's extracted **YUV420P (I420)** [MediaFrame] to packed RGBA8888.
 *
 * `startExtractMediaFrame` delivers a 3-plane planar frame (`pixFmt=0`): Y at full resolution and
 * U/V at quarter resolution (4:2:0). The capture-side [com.vyooo.insta360.pipeline.FramePipeline]
 * works on a single tightly-packed RGBA buffer, so this normalises the frame at ingestion (BT.601
 * limited range). The returned array is **reused** across frames — consume it before the next frame.
 *
 * Not thread-safe; called serially on the SDK extract thread. (CPU path; a `libyuv`/NEON or GPU
 * conversion can replace this if 30 fps full-rate processing is required.)
 */
object Insta360YuvConverter {

    private var yBuf = ByteArray(0)
    private var uBuf = ByteArray(0)
    private var vBuf = ByteArray(0)
    private var rgba = ByteArray(0)

    /** Returns the packed RGBA bytes (length `w*h*4`, reused), or null if not a 3-plane I420. */
    fun toRgba(frame: MediaFrame): ByteArray? {
        val w = frame.width
        val h = frame.height
        if (w <= 0 || h <= 0) return null
        val planes = frame.planes
        val lines = frame.lineSizes
        if (planes.size < 3) return null
        val yP = planes[0] ?: return null
        val uP = planes[1] ?: return null
        val vP = planes[2] ?: return null
        val sy = lines.getOrElse(0) { w }
        val su = lines.getOrElse(1) { w / 2 }
        val sv = lines.getOrElse(2) { w / 2 }

        val ySize = sy * h
        val uSize = su * (h / 2)
        val vSize = sv * (h / 2)
        if (yP.capacity() < ySize || uP.capacity() < uSize || vP.capacity() < vSize) return null

        if (yBuf.size < ySize) yBuf = ByteArray(ySize)
        if (uBuf.size < uSize) uBuf = ByteArray(uSize)
        if (vBuf.size < vSize) vBuf = ByteArray(vSize)
        // .clear() returns Buffer (not ByteBuffer), so keep it a statement and read on the next line.
        val yd = yP.duplicate(); yd.clear(); yd.get(yBuf, 0, ySize)
        val ud = uP.duplicate(); ud.clear(); ud.get(uBuf, 0, uSize)
        val vd = vP.duplicate(); vd.clear(); vd.get(vBuf, 0, vSize)

        val need = w * h * 4
        if (rgba.size < need) rgba = ByteArray(need)
        val dst = rgba
        val y = yBuf
        val u = uBuf
        val v = vBuf

        var di = 0
        for (row in 0 until h) {
            val yRow = row * sy
            val cRow = (row shr 1)
            val uRow = cRow * su
            val vRow = cRow * sv
            for (col in 0 until w) {
                val c = (y[yRow + col].toInt() and 0xFF) - 16
                val cc = col shr 1
                val uu = (u[uRow + cc].toInt() and 0xFF) - 128
                val vv = (v[vRow + cc].toInt() and 0xFF) - 128
                val c298 = 298 * c
                var r = (c298 + 409 * vv + 128) shr 8
                var g = (c298 - 100 * uu - 208 * vv + 128) shr 8
                var b = (c298 + 516 * uu + 128) shr 8
                if (r < 0) r = 0 else if (r > 255) r = 255
                if (g < 0) g = 0 else if (g > 255) g = 255
                if (b < 0) b = 0 else if (b > 255) b = 255
                dst[di] = r.toByte()
                dst[di + 1] = g.toByte()
                dst[di + 2] = b.toByte()
                dst[di + 3] = 255.toByte()
                di += 4
            }
        }
        return dst
    }
}
