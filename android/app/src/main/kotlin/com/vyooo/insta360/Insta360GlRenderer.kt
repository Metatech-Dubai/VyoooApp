package com.vyooo.insta360

import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface
import android.opengl.GLES20
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.view.Surface
import com.arashivision.graphicpath.insmedia.common.MediaFrame
import io.flutter.view.TextureRegistry
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * GPU renderer for the host processed display (Milestone 1, decision M1-D4) — replaces the CPU
 * I420→RGBA conversion + CPU forward-mask + `lockCanvas` upload, to reach real-time (30 fps).
 *
 * The SDK delivers a YUV420P (I420) [MediaFrame]; this renderer uploads the Y/U/V planes as GL
 * textures and runs a single fragment shader that does **BT.601 YUV→RGB and the forward-only ERP
 * mask** in one pass, rendering straight to the Flutter texture's `SurfaceTexture`. No per-pixel CPU
 * work, no bitmap copy.
 *
 * The deterministic CPU [com.vyooo.insta360.pipeline.FramePipeline] remains the reference/transport
 * implementation (used for the encoder path when re-enabled); this is the optimised display path
 * applying the same transforms (forward retain + neutral-black rear) in GLSL.
 *
 * All GL work runs on a dedicated thread; [submit] is called from the SDK extract thread and copies
 * the planes under lock before posting a draw.
 */
class Insta360GlRenderer(textureRegistry: TextureRegistry) {

    private val entry = textureRegistry.createSurfaceTexture()
    private val glThread = HandlerThread("insta360-gl").apply { start() }
    private val glHandler = Handler(glThread.looper)

    // Forward-mask params (match the CPU ForwardMaskStage defaults).
    @Volatile var forwardFovDeg: Float = 200f
    @Volatile var featherDeg: Float = 6f

    /** When false, the rear is NOT suppressed — the full 360° panorama is shown (toggle on the live feed). */
    @Volatile var maskEnabled: Boolean = true

    // Latest frame, owned by this renderer (copied off the SDK plane under [lock]).
    private val lock = Any()
    private var yBuf = ByteArray(0)
    private var uBuf = ByteArray(0)
    private var vBuf = ByteArray(0)
    private var frameW = 0
    private var frameH = 0
    private var cW = 0
    private var cH = 0
    private var hasFrame = false

    @Volatile private var renderCount = 0L

    // EGL / GL state (GL thread only).
    private var eglDisplay: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var eglContext: EGLContext = EGL14.EGL_NO_CONTEXT
    private var eglSurface: EGLSurface = EGL14.EGL_NO_SURFACE
    private var surface: Surface? = null
    private var program = 0
    private var aPos = 0
    private var aTex = 0
    private var uY = 0
    private var uU = 0
    private var uV = 0
    private var uKeep = 0
    private var uFeather = 0
    private var uMaskOn = 0
    private val texIds = IntArray(3)
    private val directBufs = arrayOfNulls<ByteBuffer>(3)
    private var surfaceW = 0
    private var surfaceH = 0

    fun create(): Long = entry.id()

    fun renderCount(): Long = renderCount

    /** Feed one I420 frame (called on the SDK extract thread). Copies planes, then posts a GL draw. */
    fun submit(frame: MediaFrame) {
        val w = frame.width
        val h = frame.height
        if (w <= 0 || h <= 0) return
        val planes = frame.planes
        if (planes.size < 3) return
        val yP = planes[0] ?: return
        val uP = planes[1] ?: return
        val vP = planes[2] ?: return
        val lines = frame.lineSizes
        val sy = lines.getOrElse(0) { w }
        val su = lines.getOrElse(1) { w / 2 }
        val sv = lines.getOrElse(2) { w / 2 }
        val cw = w / 2
        val ch = h / 2

        synchronized(lock) {
            val ySize = sy * h
            val uSize = su * ch
            val vSize = sv * ch
            if (yP.capacity() < ySize || uP.capacity() < uSize || vP.capacity() < vSize) return
            if (yBuf.size < ySize) yBuf = ByteArray(ySize)
            if (uBuf.size < uSize) uBuf = ByteArray(uSize)
            if (vBuf.size < vSize) vBuf = ByteArray(vSize)
            yP.duplicate().also { it.clear() }.get(yBuf, 0, ySize)
            uP.duplicate().also { it.clear() }.get(uBuf, 0, uSize)
            vP.duplicate().also { it.clear() }.get(vBuf, 0, vSize)
            // strides equal widths in this SDK (no row padding); keep widths for upload.
            frameW = w; frameH = h; cW = cw; cH = ch
            hasFrame = true
        }
        glHandler.post { drawFrame() }
    }

    fun dispose() {
        glHandler.post { releaseGl() }
        glThread.quitSafely()
        entry.release()
    }

    // ── GL thread ──────────────────────────────────────────────────────────────

    private fun ensureEgl(w: Int, h: Int) {
        if (eglSurface != EGL14.EGL_NO_SURFACE && surfaceW == w && surfaceH == h) return
        if (eglDisplay == EGL14.EGL_NO_DISPLAY) {
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
                    EGL14.EGL_NONE,
                ),
                0, cfg, 0, 1, n, 0,
            )
            eglContext = EGL14.eglCreateContext(
                eglDisplay, cfg[0]!!, EGL14.EGL_NO_CONTEXT,
                intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0,
            )
            this.config = cfg[0]
        }
        // (Re)create the window surface for the texture at the frame size.
        if (eglSurface != EGL14.EGL_NO_SURFACE) {
            EGL14.eglDestroySurface(eglDisplay, eglSurface)
            eglSurface = EGL14.EGL_NO_SURFACE
            surface?.release()
        }
        val st = entry.surfaceTexture()
        st.setDefaultBufferSize(w, h)
        surface = Surface(st)
        eglSurface = EGL14.eglCreateWindowSurface(
            eglDisplay, config!!, surface, intArrayOf(EGL14.EGL_NONE), 0,
        )
        EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)
        surfaceW = w; surfaceH = h
        if (program == 0) initGl()
        GLES20.glViewport(0, 0, w, h)
    }

    private var config: EGLConfig? = null

    private fun initGl() {
        program = buildProgram(VERT, FRAG)
        aPos = GLES20.glGetAttribLocation(program, "aPos")
        aTex = GLES20.glGetAttribLocation(program, "aTex")
        uY = GLES20.glGetUniformLocation(program, "uY")
        uU = GLES20.glGetUniformLocation(program, "uU")
        uV = GLES20.glGetUniformLocation(program, "uV")
        uKeep = GLES20.glGetUniformLocation(program, "uKeep")
        uFeather = GLES20.glGetUniformLocation(program, "uFeather")
        uMaskOn = GLES20.glGetUniformLocation(program, "uMaskOn")
        GLES20.glGenTextures(3, texIds, 0)
        for (t in texIds) {
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, t)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        }
        GLES20.glPixelStorei(GLES20.GL_UNPACK_ALIGNMENT, 1)
        Log.i(TAG, "GL initialised (program=$program)")
    }

    private fun drawFrame() {
        val w: Int; val h: Int; val cw: Int; val ch: Int
        synchronized(lock) {
            if (!hasFrame) return
            w = frameW; h = frameH; cw = cW; ch = cH
            try {
                ensureEgl(w, h)
                uploadPlane(0, uY, 0, yBuf, w, h)
                uploadPlane(1, uU, 1, uBuf, cw, ch)
                uploadPlane(2, uV, 2, vBuf, cw, ch)
            } catch (t: Throwable) {
                if (renderCount < 3) Log.e(TAG, "draw setup error", t)
                renderCount++
                return
            }
        }

        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        GLES20.glUseProgram(program)
        GLES20.glUniform1f(uKeep, (forwardFovDeg / 360f).coerceIn(0f, 1f))
        GLES20.glUniform1f(uFeather, (featherDeg / 360f).coerceAtLeast(0f))
        GLES20.glUniform1f(uMaskOn, if (maskEnabled) 1f else 0f)

        GLES20.glEnableVertexAttribArray(aPos)
        GLES20.glVertexAttribPointer(aPos, 2, GLES20.GL_FLOAT, false, 0, quad)
        GLES20.glEnableVertexAttribArray(aTex)
        GLES20.glVertexAttribPointer(aTex, 2, GLES20.GL_FLOAT, false, 0, tex)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

        EGL14.eglSwapBuffers(eglDisplay, eglSurface)
        if (renderCount == 0L) Log.i(TAG, "first frame rendered (${w}x$h)")
        renderCount++
    }

    private fun uploadPlane(unit: Int, sampler: Int, texIndex: Int, data: ByteArray, w: Int, h: Int) {
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0 + unit)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texIds[texIndex])
        val size = w * h
        var buf = directBufs[texIndex]
        if (buf == null || buf.capacity() < size) {
            buf = ByteBuffer.allocateDirect(size).order(ByteOrder.nativeOrder())
            directBufs[texIndex] = buf
        }
        buf.clear()
        buf.put(data, 0, size)
        buf.position(0)
        GLES20.glTexImage2D(
            GLES20.GL_TEXTURE_2D, 0, GLES20.GL_LUMINANCE, w, h, 0,
            GLES20.GL_LUMINANCE, GLES20.GL_UNSIGNED_BYTE, buf,
        )
        GLES20.glUniform1i(sampler, unit)
    }

    private fun releaseGl() {
        if (program != 0) GLES20.glDeleteProgram(program)
        if (eglDisplay != EGL14.EGL_NO_DISPLAY) {
            EGL14.eglMakeCurrent(eglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
            if (eglSurface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(eglDisplay, eglSurface)
            if (eglContext != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(eglDisplay, eglContext)
            EGL14.eglTerminate(eglDisplay)
        }
        surface?.release()
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
        if (ok[0] == 0) Log.e(TAG, "shader compile error: ${GLES20.glGetShaderInfoLog(s)}")
        return s
    }

    private companion object {
        const val TAG = "Insta360GlRenderer"

        // Fullscreen triangle strip; tex V flipped so the image is upright (image top → screen top).
        val quad: java.nio.FloatBuffer = floatBuf(floatArrayOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f))
        val tex: java.nio.FloatBuffer = floatBuf(floatArrayOf(0f, 1f, 1f, 1f, 0f, 0f, 1f, 0f))

        fun floatBuf(a: FloatArray): java.nio.FloatBuffer =
            ByteBuffer.allocateDirect(a.size * 4).order(ByteOrder.nativeOrder())
                .asFloatBuffer().apply { put(a); position(0) }

        const val VERT =
            "attribute vec2 aPos; attribute vec2 aTex; varying vec2 vTex;" +
                "void main(){ gl_Position = vec4(aPos,0.0,1.0); vTex = aTex; }"

        // BT.601 limited-range YUV->RGB + forward-only mask on the ERP horizontal axis.
        const val FRAG =
            "precision mediump float;" +
                "varying vec2 vTex;" +
                "uniform sampler2D uY; uniform sampler2D uU; uniform sampler2D uV;" +
                "uniform float uKeep; uniform float uFeather; uniform float uMaskOn;" +
                "void main(){" +
                "  float y = 1.164 * (texture2D(uY, vTex).r - 0.0625);" +
                "  float u = texture2D(uU, vTex).r - 0.5;" +
                "  float v = texture2D(uV, vTex).r - 0.5;" +
                "  float r = y + 1.596 * v;" +
                "  float g = y - 0.391 * u - 0.813 * v;" +
                "  float b = y + 2.018 * u;" +
                "  float kh = uKeep * 0.5;" +
                "  float d = abs(vTex.x - 0.5);" +
                "  float maskVal = 1.0 - smoothstep(kh - uFeather, kh, d);" +
                "  float m = mix(1.0, maskVal, uMaskOn);" + // uMaskOn=0 → full frame (unmasked)
                "  gl_FragColor = vec4(vec3(r,g,b) * m, 1.0);" +
                "}"
    }
}
