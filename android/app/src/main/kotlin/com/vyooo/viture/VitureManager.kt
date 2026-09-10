package com.vyooo.viture

import android.annotation.SuppressLint
import android.content.Context
import android.util.Log
import com.viture.sdk.ArCallback
import com.viture.sdk.ArManager
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Wraps the proprietary VITURE Android SDK ([com.viture.sdk.ArManager]) for the XR viewer feature.
 *
 * Responsibilities:
 *  1. Own the [ArManager] lifecycle (init → IMU on → register callback; and the reverse on stop).
 *  2. Parse the raw `onImu(...)` payload into a normalised head-orientation **quaternion** and expose
 *     it — with the lowest possible latency — to the native [com.vyooo.viewer.ViewerSphereRenderer]
 *     (via [currentOrientation], read on the GL thread) and, throttled, to Flutter (via [onOrientation]).
 *  3. Surface connection / SDK events to the bridge (via [onConnectionChanged] / [onEvent]).
 *
 * MONOSCOPIC 3DoF only: we call `set3D(false)` — the same equirect image is shown to both eyes and the
 * head pose is orientation-only (no positional/6DoF tracking). Stereo depth is explicitly out of scope
 * (see the build guide's "Future" note).
 *
 * ⚠️ The VITURE AAR is NOT in this repo (proprietary — see `android/app/libs/README.md`). Every call
 * into [ArManager] / [ArCallback] is written against the *documented* API and marked
 * `// TODO(hardware): verify` where the exact signature, constant, or payload layout is unconfirmed.
 */
@SuppressLint("StaticFieldLeak") // holds the application context only (see init)
object VitureManager {

    private const val TAG = "VitureManager"

    // ── IMU payload layout (CONFIRMED against the official VITURESensorDemo) ─────────────────────
    // BIG-endian floats. Euler (radians) at 0/4/8 = roll/pitch/yaw (roll=front, pitch=left, yaw=up).
    // Quaternion (W,X,Y,Z) at 20/24/28/32 when the payload is long enough (len >= 36). We prefer the
    // quaternion (no gimbal issues, cleaner to slerp).
    private const val OFFSET_EULER_ROLL = 0
    private const val OFFSET_EULER_PITCH = 4
    private const val OFFSET_EULER_YAW = 8
    private const val OFFSET_QUAT = 20

    /** A quaternion needs 4 floats starting at [OFFSET_QUAT] → bytes 20..35, i.e. length >= 36. */
    private const val QUAT_MIN_PAYLOAD = 36

    // VITURE SDK init() result codes. // TODO(hardware): verify against the shipped AAR constants
    // (the SDK exposes ArManager.ERROR_INIT_SUCCESS etc.; 0 == success is the documented convention).
    private const val ERR_INIT_SUCCESS = 0

    // ── State ──────────────────────────────────────────────────────────────────────────────────

    private var appContext: Context? = null
    private var arManager: ArManager? = null

    @Volatile private var initialized = false
    @Volatile private var imuEnabled = false

    /**
     * Latest head orientation as a **unit quaternion** in (x, y, z, w) order. Written on the SDK's IMU
     * callback thread (~120 Hz), read on the GL render thread — hence `@Volatile` on a fresh array per
     * update (publish-by-reference; readers copy immediately). Identity until the first IMU sample.
     *
     * // TODO(hardware): verify the SDK's quaternion component order (x,y,z,w vs w,x,y,z) and the axis
     * // convention; the [com.vyooo.viewer.ViewerSphereRenderer] view matrix assumes this order.
     */
    @Volatile private var orientation: FloatArray = floatArrayOf(0f, 0f, 0f, 1f)

    /** Optional throttled orientation sink for Flutter (Euler degrees, for HUD/debug). Set by the bridge. */
    @Volatile var onOrientation: ((yawDeg: Float, pitchDeg: Float, rollDeg: Float) -> Unit)? = null

    /** Connection lifecycle sink for the bridge → Flutter event channel. */
    @Volatile var onConnectionChanged: ((connected: Boolean) -> Unit)? = null

    /** Raw SDK event sink (glasses (un)plugged, DP mode change, etc.) for diagnostics. */
    @Volatile var onEvent: ((eventId: Int) -> Unit)? = null

    /** Throttle the Flutter-facing orientation callback (native render reads [orientation] directly). */
    private var lastFlutterEmitNs = 0L
    private const val FLUTTER_EMIT_INTERVAL_NS = 33_000_000L // ~30 Hz to Flutter is plenty for a HUD

    val isInitialized: Boolean get() = initialized

    /** True once IMU streaming is on. The glasses being a DP-Alt-Mode *display* means "connected" is
     *  really "the SDK opened its USB IMU endpoint" — see [VitureUsbManager]. */
    val isImuEnabled: Boolean get() = imuEnabled

    // ── Lifecycle ──────────────────────────────────────────────────────────────────────────────

    /**
     * Initialise the VITURE SDK and start the 3DoF IMU stream. Idempotent.
     *
     * @return true when init succeeded and the callback is registered. Never throws — a missing AAR /
     *         absent hardware degrades to "feature unavailable" (the bridge reports `supported=false`).
     */
    @Synchronized
    fun start(context: Context): Boolean {
        if (initialized) {
            if (!imuEnabled) setImuEnabled(true)
            return true
        }
        val ctx = context.applicationContext
        appContext = ctx
        return try {
            // getInstance(context) → init(). Returns Constants.ERROR_INIT_SUCCESS (0) on success, or a
            // negative code: NO_DEVICE (-1) / NO_PERMISSION (-2) / UNKNOWN (-3). (Confirmed against the
            // SDK constants and the official sample, which checks `== ERROR_INIT_SUCCESS`.)
            val mgr = ArManager.getInstance(ctx)
            arManager = mgr
            mgr.setLogOn(true)
            val code = mgr.init()
            if (code != ERR_INIT_SUCCESS) {
                // Not fatal: usually the glasses aren't attached yet or USB permission is pending. The
                // SDK's own UsbReceiver re-inits on attach; the caller can retry start() then.
                Log.w(TAG, "ArManager.init() = $code (glasses not ready) — feature unavailable for now")
                arManager = null
                return false
            }
            mgr.registerCallback(callback)
            // Monoscopic 2D (1920x1080@120Hz): set3D(false) keeps both eyes identical (no stereo pair).
            mgr.set3D(false)
            mgr.setImuFrequency(2) // Constants.IMU_FREQUENCE_120 = 2 → 120 Hz head-tracking.
            setImuEnabled(true)
            initialized = true
            Log.i(TAG, "VITURE SDK initialised (mono 3DoF)")
            onConnectionChanged?.invoke(true)
            true
        } catch (t: Throwable) {
            // The AAR may be absent on a dev build, or no glasses attached — never crash the app.
            Log.e(TAG, "VITURE init failed; feature unavailable", t)
            arManager = null
            initialized = false
            false
        }
    }

    /** Toggle the IMU stream without tearing down the SDK. */
    @Synchronized
    fun setImuEnabled(enabled: Boolean) {
        val mgr = arManager ?: return
        try {
            mgr.setImuOn(enabled) // TODO(hardware): verify method name/return
            imuEnabled = enabled
            Log.i(TAG, "IMU ${if (enabled) "on" else "off"}")
        } catch (t: Throwable) {
            Log.e(TAG, "setImuOn($enabled) failed", t)
        }
    }

    /** Stop the IMU stream, unregister the callback and release the SDK. Idempotent. */
    @Synchronized
    fun stop() {
        val mgr = arManager
        if (mgr != null) {
            try {
                mgr.setImuOn(false)
                mgr.unregisterCallback(callback)
                mgr.release() // ArManager.release() exists (confirmed) — frees the SDK's USB endpoints.
            } catch (t: Throwable) {
                Log.e(TAG, "stop error", t)
            }
        }
        imuEnabled = false
        initialized = false
        arManager = null
        orientation = floatArrayOf(0f, 0f, 0f, 1f)
        onConnectionChanged?.invoke(false)
        Log.i(TAG, "VITURE SDK stopped")
    }

    /**
     * The current head orientation quaternion (x, y, z, w). Returns a **copy** so the GL thread never
     * races the volatile publish. Cheap (16 bytes) and called once per rendered frame.
     */
    fun currentOrientation(out: FloatArray) {
        val q = orientation // volatile read of the latest published array
        out[0] = q[0]; out[1] = q[1]; out[2] = q[2]; out[3] = q[3]
    }

    // ── SDK callback ───────────────────────────────────────────────────────────────────────────

    private val callback = object : ArCallback() {
        override fun onImu(timestamp: Long, imuData: ByteArray?) {
            val data = imuData ?: return
            parseImu(data)
        }

        override fun onEvent(eventId: Int, event: ByteArray?, timestamp: Long) {
            // Events cover glasses attach/detach, DP mode changes, 2D/3D switches, etc. We don't decode
            // the payloads here (undocumented); the id alone drives connection UX + diagnostics.
            // TODO(hardware): map the concrete event ids (attach/detach) to refine onConnectionChanged.
            Log.i(TAG, "VITURE onEvent id=$eventId")
            onEvent?.invoke(eventId)
        }
    }

    /** Parse one IMU payload into [orientation] and (throttled) notify Flutter. */
    private fun parseImu(data: ByteArray) {
        // The SDK delivers BIG-endian floats: the official VITURESensorDemo uses
        // ByteBuffer.wrap(...).getFloat(offset) without changing the order, and wrap() defaults to
        // BIG_ENDIAN. (Confirmed against the shipped sample, not a guess.)
        val bb = ByteBuffer.wrap(data).order(ByteOrder.BIG_ENDIAN)
        if (data.size >= QUAT_MIN_PAYLOAD) {
            // Quaternion component order is **W, X, Y, Z**: W@20, X@24, Y@28, Z@32 (per the sample).
            val w = bb.getFloat(OFFSET_QUAT)
            val x = bb.getFloat(OFFSET_QUAT + 4)
            val y = bb.getFloat(OFFSET_QUAT + 8)
            val z = bb.getFloat(OFFSET_QUAT + 12)
            publishQuaternion(x, y, z, w)
        } else if (data.size >= 12) {
            // Fallback: build a quaternion from the Euler angles (radians).
            val roll = bb.getFloat(OFFSET_EULER_ROLL)
            val pitch = bb.getFloat(OFFSET_EULER_PITCH)
            val yaw = bb.getFloat(OFFSET_EULER_YAW)
            publishEuler(roll, pitch, yaw)
        }
    }

    private fun publishQuaternion(x: Float, y: Float, z: Float, w: Float) {
        // Normalise defensively (an unnormalised quat skews the rotation matrix).
        val n = Math.sqrt((x * x + y * y + z * z + w * w).toDouble()).toFloat()
        val inv = if (n > 1e-6f) 1f / n else 1f
        orientation = floatArrayOf(x * inv, y * inv, z * inv, w * inv)
        maybeEmitEuler(quatToEuler(x * inv, y * inv, z * inv, w * inv))
    }

    private fun publishEuler(roll: Float, pitch: Float, yaw: Float) {
        orientation = eulerToQuat(roll, pitch, yaw)
        maybeEmitEuler(Triple(yaw, pitch, roll))
    }

    /** Emit (yaw, pitch, roll) **degrees** to Flutter, throttled. */
    private fun maybeEmitEuler(yprRad: Triple<Float, Float, Float>) {
        val cb = onOrientation ?: return
        val now = System.nanoTime()
        if (now - lastFlutterEmitNs < FLUTTER_EMIT_INTERVAL_NS) return
        lastFlutterEmitNs = now
        val (yaw, pitch, roll) = yprRad
        cb(Math.toDegrees(yaw.toDouble()).toFloat(),
            Math.toDegrees(pitch.toDouble()).toFloat(),
            Math.toDegrees(roll.toDouble()).toFloat())
    }

    // ── Small math helpers (Z-up yaw / X-pitch / Y-roll intrinsic; verify against SDK axes) ──────

    /** Euler (radians) → unit quaternion (x, y, z, w). // TODO(hardware): verify axis order matches SDK. */
    private fun eulerToQuat(roll: Float, pitch: Float, yaw: Float): FloatArray {
        val cr = Math.cos((roll * 0.5f).toDouble()); val sr = Math.sin((roll * 0.5f).toDouble())
        val cp = Math.cos((pitch * 0.5f).toDouble()); val sp = Math.sin((pitch * 0.5f).toDouble())
        val cy = Math.cos((yaw * 0.5f).toDouble()); val sy = Math.sin((yaw * 0.5f).toDouble())
        val w = (cr * cp * cy + sr * sp * sy).toFloat()
        val x = (sr * cp * cy - cr * sp * sy).toFloat()
        val y = (cr * sp * cy + sr * cp * sy).toFloat()
        val z = (cr * cp * sy - sr * sp * cy).toFloat()
        return floatArrayOf(x, y, z, w)
    }

    /** Unit quaternion (x, y, z, w) → Euler (radians) as (yaw, pitch, roll). */
    private fun quatToEuler(x: Float, y: Float, z: Float, w: Float): Triple<Float, Float, Float> {
        val sinrCosp = 2f * (w * x + y * z)
        val cosrCosp = 1f - 2f * (x * x + y * y)
        val roll = Math.atan2(sinrCosp.toDouble(), cosrCosp.toDouble()).toFloat()
        val sinp = 2f * (w * y - z * x)
        val pitch = if (Math.abs(sinp) >= 1f) Math.copySign(Math.PI / 2, sinp.toDouble()).toFloat()
        else Math.asin(sinp.toDouble()).toFloat()
        val sinyCosp = 2f * (w * z + x * y)
        val cosyCosp = 1f - 2f * (y * y + z * z)
        val yaw = Math.atan2(sinyCosp.toDouble(), cosyCosp.toDouble()).toFloat()
        return Triple(yaw, pitch, roll)
    }
}
