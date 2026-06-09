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
import io.flutter.view.TextureRegistry
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Uploads already-processed **RGBA** frames (from [Insta360FrameSink] → the FramePipeline) to a
 * Flutter texture — the host display surface.
 *
 * It performs **no** optimisation itself: the pipeline is the single source of truth for downscale /
 * forward-mask / temporal / AI, so the host shows exactly what the pipeline produced (and what's
 * transmitted). GL is used purely for an efficient RGBA → `SurfaceTexture` upload + draw on a
 * dedicated thread. [submit] is called from the SDK extract thread and copies the buffer first.
 */
class Insta360GlRenderer(textureRegistry: TextureRegistry) {

    private val entry = textureRegistry.createSurfaceTexture()
    private val glThread = HandlerThread("insta360-gl").apply { start() }
    private val glHandler = Handler(glThread.looper)

    private val lock = Any()
    private var rgba = ByteArray(0)
    private var frameW = 0
    private var frameH = 0
    private var hasFrame = false
    @Volatile private var renderCount = 0L

    private var eglDisplay: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var eglContext: EGLContext = EGL14.EGL_NO_CONTEXT
    private var eglSurface: EGLSurface = EGL14.EGL_NO_SURFACE
    private var config: EGLConfig? = null
    private var surface: Surface? = null
    private var program = 0
    private var aPos = 0
    private var aTex = 0
    private var uTex = 0
    private var texId = 0
    private var uploadBuf: ByteBuffer? = null
    private var surfaceW = 0
    private var surfaceH = 0

    fun create(): Long = entry.id()

    /** Upload one processed RGBA frame ([src] holds at least `w*h*4` bytes). */
    fun submit(src: ByteArray, w: Int, h: Int) {
        if (w <= 0 || h <= 0 || src.size < w * h * 4) return
        synchronized(lock) {
            val need = w * h * 4
            if (rgba.size < need) rgba = ByteArray(need)
            System.arraycopy(src, 0, rgba, 0, need)
            frameW = w; frameH = h; hasFrame = true
        }
        glHandler.post { drawFrame() }
    }

    fun dispose() {
        glHandler.post { releaseGl() }
        glThread.quitSafely()
        entry.release()
    }

    // ── GL thread ──────────────────────────────────────────────────────────────

    private fun drawFrame() {
        val w: Int
        val h: Int
        synchronized(lock) {
            if (!hasFrame) return
            w = frameW; h = frameH
            try {
                ensureEgl(w, h)
                val size = w * h * 4
                var buf = uploadBuf
                if (buf == null || buf.capacity() < size) {
                    buf = ByteBuffer.allocateDirect(size).order(ByteOrder.nativeOrder())
                    uploadBuf = buf
                }
                buf.clear()
                buf.put(rgba, 0, size)
                buf.position(0)
                GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
                GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texId)
                GLES20.glTexImage2D(
                    GLES20.GL_TEXTURE_2D, 0, GLES20.GL_RGBA, w, h, 0,
                    GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, buf,
                )
            } catch (t: Throwable) {
                if (renderCount < 3) Log.e(TAG, "draw error", t)
                renderCount++
                return
            }
        }

        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        GLES20.glUseProgram(program)
        GLES20.glUniform1i(uTex, 0)
        GLES20.glEnableVertexAttribArray(aPos)
        GLES20.glVertexAttribPointer(aPos, 2, GLES20.GL_FLOAT, false, 0, quad)
        GLES20.glEnableVertexAttribArray(aTex)
        GLES20.glVertexAttribPointer(aTex, 2, GLES20.GL_FLOAT, false, 0, tex)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        EGL14.eglSwapBuffers(eglDisplay, eglSurface)
        if (renderCount == 0L) Log.i(TAG, "first frame uploaded (${w}x$h)")
        renderCount++
    }

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
            config = cfg[0]
            eglContext = EGL14.eglCreateContext(
                eglDisplay, cfg[0]!!, EGL14.EGL_NO_CONTEXT,
                intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0,
            )
        }
        if (eglSurface != EGL14.EGL_NO_SURFACE) {
            EGL14.eglDestroySurface(eglDisplay, eglSurface)
            eglSurface = EGL14.EGL_NO_SURFACE
            surface?.release()
        }
        val st = entry.surfaceTexture()
        st.setDefaultBufferSize(w, h)
        surface = Surface(st)
        eglSurface = EGL14.eglCreateWindowSurface(eglDisplay, config!!, surface, intArrayOf(EGL14.EGL_NONE), 0)
        EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)
        surfaceW = w; surfaceH = h
        if (program == 0) initGl()
        GLES20.glViewport(0, 0, w, h)
    }

    private fun initGl() {
        program = buildProgram(VERT, FRAG)
        aPos = GLES20.glGetAttribLocation(program, "aPos")
        aTex = GLES20.glGetAttribLocation(program, "aTex")
        uTex = GLES20.glGetUniformLocation(program, "uTex")
        val t = IntArray(1)
        GLES20.glGenTextures(1, t, 0)
        texId = t[0]
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texId)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glPixelStorei(GLES20.GL_UNPACK_ALIGNMENT, 1)
        Log.i(TAG, "GL uploader initialised")
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
        if (ok[0] == 0) Log.e(TAG, "shader error: ${GLES20.glGetShaderInfoLog(s)}")
        return s
    }

    private companion object {
        const val TAG = "Insta360GlRenderer"

        // Fullscreen triangle strip; tex V flipped so the image is upright.
        val quad: java.nio.FloatBuffer = floatBuf(floatArrayOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f))
        val tex: java.nio.FloatBuffer = floatBuf(floatArrayOf(0f, 1f, 1f, 1f, 0f, 0f, 1f, 0f))

        fun floatBuf(a: FloatArray): java.nio.FloatBuffer =
            ByteBuffer.allocateDirect(a.size * 4).order(ByteOrder.nativeOrder())
                .asFloatBuffer().apply { put(a); position(0) }

        const val VERT =
            "attribute vec2 aPos; attribute vec2 aTex; varying vec2 vTex;" +
                "void main(){ gl_Position = vec4(aPos,0.0,1.0); vTex = aTex; }"

        const val FRAG =
            "precision mediump float; varying vec2 vTex; uniform sampler2D uTex;" +
                "void main(){ gl_FragColor = texture2D(uTex, vTex); }"
    }
}
