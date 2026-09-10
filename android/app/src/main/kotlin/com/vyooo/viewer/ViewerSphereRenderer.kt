package com.vyooo.viewer

import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface
import android.opengl.GLES20
import android.opengl.Matrix
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.view.Surface
import com.vyooo.viture.VitureManager
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.nio.ShortBuffer

/**
 * OpenGL ES 2.0 renderer that draws a monoscopic **360° equirectangular (ERP)** stream onto the inside
 * of a UV-sphere, with the camera orientation driven by the VITURE head pose ([VitureManager]) for a
 * head-tracked view. This is the viewer-side equivalent of the host's Insta360 sphere preview.
 *
 * EGL / GL-thread / Flutter-`SurfaceTexture` scaffolding is adapted from
 * [com.vyooo.insta360.Insta360GlRenderer] (which only draws a flat quad). What is added here:
 *  - **Geometry**: a generated UV-sphere (positions + equirect UVs + indices).
 *  - **Shaders**: an MVP vertex shader; a fragment shader that samples the ERP frame delivered as
 *    **I420 (Y/U/V planes)** and converts to RGB (BT.601 limited range) in one pass — so the sphere
 *    sampling and the colour conversion happen together on the GPU.
 *  - **A vsync-paced render loop** that redraws on every display tick (not only on a new video frame),
 *    because the *head* moves at ~120 Hz even when the video is at 30 fps — the pose must keep the view
 *    responsive between frames (this is what makes head-tracking feel locked to the world).
 *  - **MVP rotation = head orientation** (quaternion → view matrix), with a method-channel
 *    [setExternalOrientation] override for a touch/gyro fallback when no glasses are attached.
 *
 * Frames arrive via [submitYuv] from the Agora video-frame observer (pushed down from Dart). MONOSCOPIC
 * only: one texture set, one draw — both eyes see the same image via DP-Alt-Mode mirroring.
 */
class ViewerSphereRenderer(private val surface: Surface) {

    private val glThread = HandlerThread("viewer-sphere-gl").apply { start() }
    private val glHandler = Handler(glThread.looper)

    @Volatile private var running = false
    @Volatile private var renderCount = 0L

    // ── Latest frame (written by submitYuv on the Agora observer thread; read on the GL thread) ──
    private val frameLock = Any()
    private var yPacked = ByteArray(0)
    private var uPacked = ByteArray(0)
    private var vPacked = ByteArray(0)
    private var frameW = 0
    private var frameH = 0
    private var frameDirty = false
    private var hasFrame = false

    // ── Orientation override (touch/gyro fallback), degrees ──
    @Volatile private var useExternalOrientation = false
    @Volatile private var extYawDeg = 0f
    @Volatile private var extPitchDeg = 0f

    // ── EGL / GL objects ──
    private var eglDisplay: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var eglContext: EGLContext = EGL14.EGL_NO_CONTEXT
    private var eglSurface: EGLSurface = EGL14.EGL_NO_SURFACE
    private var program = 0
    private var aPos = 0
    private var aUv = 0
    private var uMvp = 0
    private var uTexY = 0
    private var uTexU = 0
    private var uTexV = 0
    private var texY = 0
    private var texU = 0
    private var texV = 0
    private var surfaceW = 0
    private var surfaceH = 0

    // Geometry buffers
    private lateinit var vertexBuf: FloatBuffer
    private lateinit var uvBuf: FloatBuffer
    private lateinit var indexBuf: ShortBuffer
    private var indexCount = 0

    // Matrices (column-major, android.opengl.Matrix convention)
    private val projection = FloatArray(16)
    private val view = FloatArray(16)
    private val mvp = FloatArray(16)
    private val rotation = FloatArray(16)
    private val quat = FloatArray(4)

    // Upload scratch buffers (direct, reused)
    private var yUpload: ByteBuffer? = null
    private var uUpload: ByteBuffer? = null
    private var vUpload: ByteBuffer? = null

    /** Start the EGL context and the vsync render loop on the GL thread. */
    fun start(width: Int, height: Int) {
        surfaceW = width
        surfaceH = height
        running = true
        glHandler.post {
            initEgl()
            initGl()
            buildSphere(RINGS, SECTORS)
            updateProjection(surfaceW, surfaceH)
            scheduleFrame()
        }
    }

    /** Resize the render surface (e.g. platform-view layout change). */
    fun resize(width: Int, height: Int) {
        glHandler.post {
            surfaceW = width
            surfaceH = height
            if (eglSurface != EGL14.EGL_NO_SURFACE) {
                GLES20.glViewport(0, 0, width, height)
                updateProjection(width, height)
            }
        }
    }

    /**
     * Push one ERP frame as **I420** planes. Buffers may be strided (`*Stride` >= plane width); we
     * repack to contiguous rows here (ES2 has no `GL_UNPACK_ROW_LENGTH`). Called from the Agora
     * observer thread; copies immediately so the caller may recycle its buffers.
     */
    fun submitYuv(
        y: ByteArray, u: ByteArray, v: ByteArray,
        width: Int, height: Int,
        yStride: Int, uStride: Int, vStride: Int,
    ) {
        if (width <= 0 || height <= 0) return
        val cw = width / 2
        val ch = height / 2
        synchronized(frameLock) {
            val ySize = width * height
            val cSize = cw * ch
            if (yPacked.size < ySize) yPacked = ByteArray(ySize)
            if (uPacked.size < cSize) uPacked = ByteArray(cSize)
            if (vPacked.size < cSize) vPacked = ByteArray(cSize)
            repackPlane(y, yPacked, width, height, yStride)
            repackPlane(u, uPacked, cw, ch, uStride)
            repackPlane(v, vPacked, cw, ch, vStride)
            frameW = width
            frameH = height
            frameDirty = true
            hasFrame = true
        }
    }

    /** Enable/disable the touch/gyro orientation override (yaw/pitch in degrees). */
    fun setExternalOrientation(yawDeg: Float, pitchDeg: Float) {
        extYawDeg = yawDeg
        extPitchDeg = pitchDeg
        useExternalOrientation = true
    }

    /** Return control of the camera to the VITURE head pose. */
    fun clearExternalOrientation() {
        useExternalOrientation = false
    }

    fun dispose() {
        running = false
        glHandler.post { releaseGl() }
        glThread.quitSafely()
    }

    // ── GL thread: render loop ───────────────────────────────────────────────────────────────────

    private fun scheduleFrame() {
        if (!running) return
        // A fixed cadence keeps the head-tracked view responsive between (slower) video frames. The
        // glasses run at 120 Hz; matching that is ideal for motion-to-photon, but a Handler cadence is
        // approximate. // TODO(hardware): drive from Choreographer / the external display's vsync for
        // precise 120 Hz pacing on the glasses.
        drawFrame()
        glHandler.postDelayed({ scheduleFrame() }, FRAME_INTERVAL_MS)
    }

    private fun drawFrame() {
        if (eglSurface == EGL14.EGL_NO_SURFACE || program == 0) return
        try {
            // 1. Upload a new video frame if one arrived since the last draw.
            uploadFrameIfDirty()

            // 2. Build the view matrix from the current head orientation (or the override).
            computeViewMatrix()
            Matrix.multiplyMM(mvp, 0, projection, 0, view, 0)

            // 3. Draw the sphere from the inside.
            GLES20.glClearColor(0f, 0f, 0f, 1f)
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
            if (!hasFrame) {
                // Nothing to show yet — a black sphere avoids a flash of garbage.
                EGL14.eglSwapBuffers(eglDisplay, eglSurface)
                return
            }
            GLES20.glUseProgram(program)
            GLES20.glUniformMatrix4fv(uMvp, 1, false, mvp, 0)

            bindPlane(GLES20.GL_TEXTURE0, texY, uTexY, 0)
            bindPlane(GLES20.GL_TEXTURE1, texU, uTexU, 1)
            bindPlane(GLES20.GL_TEXTURE2, texV, uTexV, 2)

            GLES20.glEnableVertexAttribArray(aPos)
            GLES20.glVertexAttribPointer(aPos, 3, GLES20.GL_FLOAT, false, 0, vertexBuf)
            GLES20.glEnableVertexAttribArray(aUv)
            GLES20.glVertexAttribPointer(aUv, 2, GLES20.GL_FLOAT, false, 0, uvBuf)
            GLES20.glDrawElements(GLES20.GL_TRIANGLES, indexCount, GLES20.GL_UNSIGNED_SHORT, indexBuf)

            EGL14.eglSwapBuffers(eglDisplay, eglSurface)
            if (renderCount == 0L) Log.i(TAG, "first sphere frame drawn (${frameW}x$frameH)")
            renderCount++
        } catch (t: Throwable) {
            if (renderCount < 3) Log.e(TAG, "draw error", t)
            renderCount++
        }
    }

    private fun uploadFrameIfDirty() {
        val w: Int; val h: Int
        synchronized(frameLock) {
            if (!frameDirty) return
            w = frameW; h = frameH
            frameDirty = false
            yUpload = ensureDirect(yUpload, w * h).also { it.clear(); it.put(yPacked, 0, w * h); it.position(0) }
            val cw = w / 2; val ch = h / 2
            uUpload = ensureDirect(uUpload, cw * ch).also { it.clear(); it.put(uPacked, 0, cw * ch); it.position(0) }
            vUpload = ensureDirect(vUpload, cw * ch).also { it.clear(); it.put(vPacked, 0, cw * ch); it.position(0) }
        }
        val cw = w / 2; val ch = h / 2
        uploadLuma(texY, w, h, yUpload!!)
        uploadLuma(texU, cw, ch, uUpload!!)
        uploadLuma(texV, cw, ch, vUpload!!)
    }

    private fun uploadLuma(tex: Int, w: Int, h: Int, buf: ByteBuffer) {
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, tex)
        GLES20.glTexImage2D(
            GLES20.GL_TEXTURE_2D, 0, GLES20.GL_LUMINANCE, w, h, 0,
            GLES20.GL_LUMINANCE, GLES20.GL_UNSIGNED_BYTE, buf,
        )
    }

    private fun bindPlane(unit: Int, tex: Int, uniform: Int, index: Int) {
        GLES20.glActiveTexture(unit)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, tex)
        GLES20.glUniform1i(uniform, index)
    }

    /**
     * Build the world→camera view matrix. The head orientation quaternion describes the *camera*'s
     * orientation in the world; the view matrix is its inverse. We look from the sphere centre, so
     * only rotation matters (no translation).
     *
     * // TODO(hardware): verify axis mapping & handedness. If the world spins the wrong way when the
     * // head turns, transpose `rotation` (use it directly instead of as the inverse) or negate the
     * // quaternion's vector part; if up/down or left/right is mirrored, flip the corresponding axis.
     */
    private fun computeViewMatrix() {
        if (useExternalOrientation) {
            // Touch/gyro fallback: yaw about world-up (Y), pitch about camera-right (X).
            Matrix.setIdentityM(view, 0)
            Matrix.rotateM(view, 0, -extPitchDeg, 1f, 0f, 0f)
            Matrix.rotateM(view, 0, -extYawDeg, 0f, 1f, 0f)
            return
        }
        VitureManager.currentOrientation(quat)
        quatToMatrix(quat, rotation)
        // Inverse of a pure rotation is its transpose → world→camera.
        Matrix.transposeM(view, 0, rotation, 0)
    }

    // ── GL setup ─────────────────────────────────────────────────────────────────────────────────

    private fun initEgl() {
        eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        val ver = IntArray(2)
        EGL14.eglInitialize(eglDisplay, ver, 0, ver, 1)
        val cfg = arrayOfNulls<EGLConfig>(1)
        val n = IntArray(1)
        EGL14.eglChooseConfig(
            eglDisplay,
            intArrayOf(
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_SURFACE_TYPE, EGL14.EGL_WINDOW_BIT,
                EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8,
                EGL14.EGL_BLUE_SIZE, 8, EGL14.EGL_ALPHA_SIZE, 8,
                EGL14.EGL_DEPTH_SIZE, 16,
                EGL14.EGL_NONE,
            ),
            0, cfg, 0, 1, n, 0,
        )
        eglContext = EGL14.eglCreateContext(
            eglDisplay, cfg[0]!!, EGL14.EGL_NO_CONTEXT,
            intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0,
        )
        eglSurface = EGL14.eglCreateWindowSurface(eglDisplay, cfg[0]!!, surface, intArrayOf(EGL14.EGL_NONE), 0)
        EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)
    }

    private fun initGl() {
        program = buildProgram(VERT, FRAG)
        aPos = GLES20.glGetAttribLocation(program, "aPos")
        aUv = GLES20.glGetAttribLocation(program, "aUv")
        uMvp = GLES20.glGetUniformLocation(program, "uMvp")
        uTexY = GLES20.glGetUniformLocation(program, "uTexY")
        uTexU = GLES20.glGetUniformLocation(program, "uTexU")
        uTexV = GLES20.glGetUniformLocation(program, "uTexV")
        val t = IntArray(3)
        GLES20.glGenTextures(3, t, 0)
        texY = t[0]; texU = t[1]; texV = t[2]
        for (id in t) {
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, id)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        }
        GLES20.glPixelStorei(GLES20.GL_UNPACK_ALIGNMENT, 1)
        // We render the sphere from the *inside*: cull nothing (both faces valid) and keep depth on.
        GLES20.glDisable(GLES20.GL_CULL_FACE)
        GLES20.glEnable(GLES20.GL_DEPTH_TEST)
        GLES20.glViewport(0, 0, surfaceW, surfaceH)
        Log.i(TAG, "GL sphere renderer initialised")
    }

    private fun updateProjection(w: Int, h: Int) {
        val aspect = if (h > 0) w.toFloat() / h.toFloat() else 1f
        // Vertical FOV of the virtual camera. // TODO(hardware): match the VITURE Luma's real display
        // FOV (~40-46° diagonal) so the world scale looks correct on the glasses.
        Matrix.perspectiveM(projection, 0, VERTICAL_FOV_DEG, aspect, 0.1f, 10f)
    }

    /**
     * Generate a UV-sphere of radius 1. Vertex `(x,y,z)` from spherical coords; UV maps longitude→u,
     * latitude→v so an equirectangular image wraps correctly. `v` is flipped so image row 0 (top) maps
     * to the north pole. // TODO(hardware): verify the V flip once a live frame renders (seam/pole).
     */
    private fun buildSphere(rings: Int, sectors: Int) {
        val positions = ArrayList<Float>()
        val uvs = ArrayList<Float>()
        for (r in 0..rings) {
            val theta = Math.PI * r / rings                    // 0 (north pole) .. PI (south)
            val sinT = Math.sin(theta); val cosT = Math.cos(theta)
            for (s in 0..sectors) {
                val phi = 2.0 * Math.PI * s / sectors          // 0 .. 2PI
                val sinP = Math.sin(phi); val cosP = Math.cos(phi)
                positions.add((sinT * cosP).toFloat())
                positions.add(cosT.toFloat())
                positions.add((sinT * sinP).toFloat())
                uvs.add((s.toFloat() / sectors))               // u = longitude
                uvs.add((r.toFloat() / rings))                 // v = latitude (0 = top = north pole)
            }
        }
        val indices = ArrayList<Short>()
        val stride = sectors + 1
        for (r in 0 until rings) {
            for (s in 0 until sectors) {
                val a = (r * stride + s).toShort()
                val b = (r * stride + s + 1).toShort()
                val c = ((r + 1) * stride + s).toShort()
                val d = ((r + 1) * stride + s + 1).toShort()
                indices.add(a); indices.add(c); indices.add(b)
                indices.add(b); indices.add(c); indices.add(d)
            }
        }
        indexCount = indices.size
        vertexBuf = floatBuf(positions.toFloatArray())
        uvBuf = floatBuf(uvs.toFloatArray())
        indexBuf = ByteBuffer.allocateDirect(indices.size * 2).order(ByteOrder.nativeOrder())
            .asShortBuffer().apply { indices.forEach { put(it) }; position(0) }
        Log.i(TAG, "sphere built: ${positions.size / 3} verts, $indexCount indices")
    }

    private fun releaseGl() {
        if (program != 0) GLES20.glDeleteProgram(program)
        val t = intArrayOf(texY, texU, texV)
        if (texY != 0) GLES20.glDeleteTextures(3, t, 0)
        if (eglDisplay != EGL14.EGL_NO_DISPLAY) {
            EGL14.eglMakeCurrent(eglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
            if (eglSurface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(eglDisplay, eglSurface)
            if (eglContext != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(eglDisplay, eglContext)
            EGL14.eglTerminate(eglDisplay)
        }
        eglDisplay = EGL14.EGL_NO_DISPLAY
        eglSurface = EGL14.EGL_NO_SURFACE
        eglContext = EGL14.EGL_NO_CONTEXT
        program = 0
    }

    private fun buildProgram(vs: String, fs: String): Int {
        val v = compile(GLES20.GL_VERTEX_SHADER, vs)
        val f = compile(GLES20.GL_FRAGMENT_SHADER, fs)
        val p = GLES20.glCreateProgram()
        GLES20.glAttachShader(p, v)
        GLES20.glAttachShader(p, f)
        GLES20.glLinkProgram(p)
        val ok = IntArray(1)
        GLES20.glGetProgramiv(p, GLES20.GL_LINK_STATUS, ok, 0)
        if (ok[0] == 0) Log.e(TAG, "link error: ${GLES20.glGetProgramInfoLog(p)}")
        return p
    }

    private fun compile(type: Int, src: String): Int {
        val s = GLES20.glCreateShader(type)
        GLES20.glShaderSource(s, src)
        GLES20.glCompileShader(s)
        val ok = IntArray(1)
        GLES20.glGetShaderiv(s, GLES20.GL_COMPILE_STATUS, ok, 0)
        if (ok[0] == 0) Log.e(TAG, "shader error: ${GLES20.glGetShaderInfoLog(s)}")
        return s
    }

    // ── Utilities ────────────────────────────────────────────────────────────────────────────────

    /** Copy `w*h` bytes from a possibly-strided source into a contiguous `dst`. */
    private fun repackPlane(src: ByteArray, dst: ByteArray, w: Int, h: Int, stride: Int) {
        if (stride == w && src.size >= w * h) {
            System.arraycopy(src, 0, dst, 0, w * h)
            return
        }
        var d = 0
        var s = 0
        for (row in 0 until h) {
            if (s + w > src.size) break
            System.arraycopy(src, s, dst, d, w)
            d += w
            s += stride
        }
    }

    private fun ensureDirect(buf: ByteBuffer?, size: Int): ByteBuffer =
        if (buf != null && buf.capacity() >= size) buf
        else ByteBuffer.allocateDirect(size).order(ByteOrder.nativeOrder())

    /** Unit quaternion (x, y, z, w) → column-major 4x4 rotation matrix. */
    private fun quatToMatrix(q: FloatArray, m: FloatArray) {
        val x = q[0]; val y = q[1]; val z = q[2]; val w = q[3]
        val xx = x * x; val yy = y * y; val zz = z * z
        val xy = x * y; val xz = x * z; val yz = y * z
        val wx = w * x; val wy = w * y; val wz = w * z
        m[0] = 1f - 2f * (yy + zz); m[1] = 2f * (xy + wz);      m[2] = 2f * (xz - wy);      m[3] = 0f
        m[4] = 2f * (xy - wz);      m[5] = 1f - 2f * (xx + zz); m[6] = 2f * (yz + wx);      m[7] = 0f
        m[8] = 2f * (xz + wy);      m[9] = 2f * (yz - wx);      m[10] = 1f - 2f * (xx + yy); m[11] = 0f
        m[12] = 0f; m[13] = 0f; m[14] = 0f; m[15] = 1f
    }

    private fun floatBuf(a: FloatArray): FloatBuffer =
        ByteBuffer.allocateDirect(a.size * 4).order(ByteOrder.nativeOrder())
            .asFloatBuffer().apply { put(a); position(0) }

    private companion object {
        const val TAG = "ViewerSphereRenderer"
        const val RINGS = 64
        const val SECTORS = 128
        const val VERTICAL_FOV_DEG = 60f
        const val FRAME_INTERVAL_MS = 8L // ~120 Hz cadence target (approximate)

        // Vertex: standard MVP; pass equirect UV straight through.
        const val VERT = """
            attribute vec3 aPos;
            attribute vec2 aUv;
            uniform mat4 uMvp;
            varying vec2 vUv;
            void main() {
                vUv = aUv;
                gl_Position = uMvp * vec4(aPos, 1.0);
            }
        """

        // Fragment: sample I420 (Y full-res, U/V quarter-res) and convert to RGB (BT.601 limited
        // range, matching Insta360YuvConverter's coefficients).
        const val FRAG = """
            precision mediump float;
            varying vec2 vUv;
            uniform sampler2D uTexY;
            uniform sampler2D uTexU;
            uniform sampler2D uTexV;
            void main() {
                float y = texture2D(uTexY, vUv).r;
                float u = texture2D(uTexU, vUv).r - 0.5;
                float v = texture2D(uTexV, vUv).r - 0.5;
                y = 1.1643 * (y - 0.0625);
                float r = y + 1.5958 * v;
                float g = y - 0.3917 * u - 0.8129 * v;
                float b = y + 2.0170 * u;
                gl_FragColor = vec4(r, g, b, 1.0);
            }
        """
    }
}
