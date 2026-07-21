package com.vyooo.insta360

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.arashivision.insta360.basecamera.camera.CameraType
import com.arashivision.insta360.basecamera.camera.CameraWifiPrefix
import com.arashivision.sdkcamera.camera.InstaCameraManager
import com.arashivision.sdkcamera.camera.callback.ICameraChangedCallback
import com.vyooo.Insta360Support
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

/**
 * Native bridge for the Insta360 capture feature.
 *
 * Owns the camera connection lifecycle and fans status + frame events to Flutter:
 *  - MethodChannel `vyooo/insta360`         — control (connect/disconnect/streaming/status)
 *  - EventChannel  `vyooo/insta360/events`  — connection/preview/frameStats/error events
 *  - EventChannel  `vyooo/insta360/frames`  — raw RGBA frames (debug)
 *
 * The actual preview render + frame extraction lives in [Insta360PreviewView] (a PlatformView),
 * which writes to [Insta360FrameSink]; this bridge connects that sink to the event channels.
 */
class Insta360Bridge(
    private val context: Context,
    messenger: BinaryMessenger,
    private val textureRegistry: TextureRegistry,
) : MethodChannel.MethodCallHandler {

    private var glRenderer: Insta360GlRenderer? = null

    private val main = Handler(Looper.getMainLooper())
    private val methodChannel = MethodChannel(messenger, "vyooo/insta360")
    private val eventChannel = EventChannel(messenger, "vyooo/insta360/events")
    private val frameChannel = EventChannel(messenger, "vyooo/insta360/frames")

    private var events: EventChannel.EventSink? = null
    private var cameraCallbackRegistered = false

    // ── Connect state ─────────────────────────────────────────────────────────────────────────
    // Mirrors the SDK demo's ConnectViewModel (ConnectViewModel.kt:52-59, 106, 122): the demo tracks
    // isConnectingWiFi / isConnectingUsb and derives isConnected from cameraConnectedType. We were
    // missing this entirely — a second openCamera() at a camera already mid-session is what leaves
    // the stuck session that then reports 4403 ("camera due to occupied") until it is power-cycled.

    /** True from the moment `connect` is accepted until it succeeds, fails terminally, or is cancelled. */
    private var connectRequested = false
    private var isConnectingUsb = false
    private var isConnectingWifi = false

    /** True while the process is bound to the camera's Wi-Fi network (must never outlive a session). */
    private var wifiBound = false

    /** Auto-retry bookkeeping for transient connect failures (never for 4403). */
    private var retryCount = 0

    /** ConnectViewModel.kt:56-59 — "connected" means the SDK holds a live BLE/Wi-Fi/USB session. */
    private val isConnected: Boolean
        get() = try {
            InstaCameraManager.getInstance().cameraConnectedType != InstaCameraManager.CONNECT_TYPE_NONE
        } catch (t: Throwable) {
            false
        }

    private val isConnecting: Boolean
        get() = isConnectingUsb || isConnectingWifi

    private val connectivityManager: ConnectivityManager =
        context.applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val wifiManager: WifiManager =
        context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager

    init {
        methodChannel.setMethodCallHandler(this)

        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                events = sink
                Insta360FrameSink.onStats = { w, h, fps, count ->
                    send("frameStats", mapOf("width" to w, "height" to h, "fps" to fps, "count" to count))
                }
                // Host preview lifecycle ("warming" → "ready") so the UI can hold its overlay.
                Insta360PreviewView.onPreviewState = { state ->
                    send("previewState", mapOf("state" to state))
                }
            }
            override fun onCancel(arguments: Any?) {
                events = null
                Insta360FrameSink.onStats = null
                Insta360PreviewView.onPreviewState = null
            }
        })

        frameChannel.setStreamHandler(object : EventChannel.StreamHandler {
            // Single-slot coalescing dispatch. Each frame is a ~7 MB RGBA byte array; posting every
            // one straight through `main.post { sink.success(..) }` let the main-thread queue grow
            // unbounded whenever the UI got busy (notably when a viewer joins), and StandardMethodCodec
            // allocates a *fresh* ~7 MB direct buffer per delivery — together that OOM-crashed the app
            // (java.lang.OutOfMemoryError in StandardMethodCodec.encodeSuccessEnvelope from here).
            // A live stream only needs the most recent frame, so we keep just the latest one pending
            // and drop stale frames: memory stays bounded to ~1 in-flight + 1 pending, regardless of
            // main-thread load.
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                val pending = java.util.concurrent.atomic.AtomicReference<Map<String, Any?>?>(null)
                val drain = Runnable {
                    val frame = pending.getAndSet(null) ?: return@Runnable
                    sink?.success(frame)
                }
                Insta360FrameSink.onFrame = { bytes, w, h, ptsUs ->
                    val frame = mapOf("bytes" to bytes, "width" to w, "height" to h, "ptsUs" to ptsUs)
                    // If a frame is already queued, replace it (drop the stale one) instead of posting
                    // another runnable — that replacement is what bounds the backlog.
                    if (pending.getAndSet(frame) == null) main.post(drain)
                }
            }
            override fun onCancel(arguments: Any?) {
                Insta360FrameSink.onFrame = null
            }
        })
    }

    fun dispose() {
        // An in-flight connect must not outlive the bridge (its callbacks would re-open a camera
        // nobody is listening to), and the process must not stay bound to the camera's network.
        connectRequested = false
        isConnectingUsb = false
        isConnectingWifi = false
        Insta360UsbManager.cancelPending()
        // Only when no session is live — an active Wi-Fi preview still needs the binding, and the
        // Dart side disconnects explicitly before tearing the screen down.
        if (!isConnected) unbindCameraNetwork()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        frameChannel.setStreamHandler(null)
        Insta360FrameSink.onStats = null
        Insta360FrameSink.onFrame = null
        Insta360FrameSink.onProcessedFrame = null
        Insta360PreviewView.onPreviewState = null
        glRenderer?.dispose()
        glRenderer = null
        events = null
    }

    override fun onMethodCall(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(Insta360Support.isSupported)

            "connect" -> {
                if (!Insta360Support.isSupported) {
                    result.error("unsupported", "Insta360 unavailable on this device", Insta360Support.initError)
                    return
                }
                // T1 — connect-state guard (ConnectViewModel.kt:52-59). Re-entering openCamera() on a
                // camera that is already open/opening is what creates the stuck session behind 4403,
                // so a double-tap on the picker is answered with a benign status, not a second open.
                if (isConnected) {
                    Log.i(TAG, "connect ignored: already connected (type=${cameraConnectedType()})")
                    result.success(mapOf("status" to STATUS_ALREADY_CONNECTED))
                    return
                }
                if (isConnecting) {
                    Log.i(TAG, "connect ignored: already connecting (usb=$isConnectingUsb wifi=$isConnectingWifi)")
                    result.success(mapOf("status" to STATUS_ALREADY_CONNECTING))
                    return
                }

                val type = call.argument<String>("type") ?: "usb"
                ensureCameraCallback()
                connectRequested = true
                retryCount = 0
                if (type == "wifi") beginWifiConnect(result) else beginUsbConnect(result)
            }

            "disconnect" -> {
                connectRequested = false
                isConnectingUsb = false
                isConnectingWifi = false
                retryCount = 0
                Insta360UsbManager.cancelPending()
                try {
                    InstaCameraManager.getInstance().closeCamera()
                } catch (t: Throwable) {
                    Log.e(TAG, "disconnect error", t)
                }
                // Release the camera-network binding so the rest of the app regains normal routing.
                unbindCameraNetwork()
                result.success(null)
            }

            "setFrameStreaming" -> {
                Insta360FrameSink.streamingEnabled = call.argument<Boolean>("enabled") ?: false
                result.success(null)
            }

            "getPipelineMetrics" -> result.success(Insta360FrameSink.metrics())

            "createProcessedTexture" -> {
                // Host-visible Flutter texture fed the pipeline's processed RGBA frames.
                val renderer = glRenderer
                    ?: Insta360GlRenderer(textureRegistry).also { glRenderer = it }
                val id = renderer.create()
                Insta360FrameSink.onProcessedFrame = { b, w, h, _ -> renderer.submit(b, w, h) }
                result.success(id)
            }

            "disposeProcessedTexture" -> {
                Insta360FrameSink.onProcessedFrame = null
                glRenderer?.dispose()
                glRenderer = null
                result.success(null)
            }

            "setMaskEnabled" -> {
                // Toggle forward-only masking in the pipeline (true = masked, false = full 360°).
                Insta360FrameSink.setMaskEnabled(call.argument<Boolean>("enabled") ?: true)
                result.success(null)
            }

            "setTemporalEnabled" -> {
                // Toggle temporal redundancy reduction (1-in-N + motion gating) for A/B / KPI capture.
                Insta360FrameSink.setTemporalEnabled(call.argument<Boolean>("enabled") ?: true)
                result.success(null)
            }

            "setAiEnabled" -> {
                // Toggle the M3 heuristic decision layer (off = deterministic fall-open) for A/B.
                Insta360FrameSink.setAiEnabled(call.argument<Boolean>("enabled") ?: true)
                result.success(null)
            }

            "setViewOrientation" -> {
                // Drive the interactive 360 view from Flutter-side drag (degrees).
                val yaw = (call.argument<Double>("yaw") ?: 0.0).toFloat()
                val pitch = (call.argument<Double>("pitch") ?: 0.0).toFloat()
                Insta360PreviewView.applyOrientation(yaw, pitch)
                result.success(null)
            }

            "getStatus" -> result.success(status())

            else -> result.notImplemented()
        }
    }

    // ── Connect: USB ──────────────────────────────────────────────────────────────────────────

    /**
     * T2 — USB permission pre-flight. `openCamera(CONNECT_TYPE_USB)` does not wait for the Android
     * USB dialog, so a missed/slow grant times the SDK's CHECK_TYPE handshake out as **2002**. We
     * therefore hold the open back until permission is in hand (SDK demo: `usb/UsbMgr.kt:86-97`).
     */
    private fun beginUsbConnect(result: MethodChannel.Result) {
        val preflight = try {
            Insta360UsbManager.preflight(
                onGranted = { main.post { openUsbCamera() } },
                onDenied = { main.post { failConnect(ERR_USB_PERMISSION) } },
            )
        } catch (t: Throwable) {
            Log.e(TAG, "usb preflight failed", t)
            Insta360UsbManager.Preflight.GRANTED // never block a connect on our own pre-flight
        }

        when (preflight) {
            Insta360UsbManager.Preflight.NO_DEVICE -> {
                connectRequested = false
                Log.w(TAG, "usb: no device attached; devices=${Insta360UsbManager.describeAttached()}")
                result.error(
                    "usb_no_device",
                    "No camera found on USB. Plug the camera in with a USB-C data cable " +
                        "(and enable OTG/USB-host if your phone asks), then try again.",
                    null,
                )
            }

            Insta360UsbManager.Preflight.REQUESTED -> {
                // The dialog is up; openCamera() runs from the grant callback.
                Log.i(TAG, "usb: awaiting USB permission before openCamera()")
                result.success(mapOf("status" to STATUS_AWAITING_USB_PERMISSION))
            }

            Insta360UsbManager.Preflight.GRANTED -> {
                if (openUsbCamera()) {
                    result.success(mapOf("status" to STATUS_CONNECTING))
                } else {
                    result.error("connect_failed", connectErrorMessage(ERR_UNKNOWN), null)
                }
            }
        }
    }

    /** Issues the actual USB open. Returns false if the SDK threw. */
    private fun openUsbCamera(): Boolean {
        if (!connectRequested) return false // cancelled while the dialog was up
        return try {
            isConnectingUsb = true
            Log.i(TAG, "usb: openCamera(CONNECT_TYPE_USB) attempt=${retryCount + 1}")
            InstaCameraManager.getInstance().openCamera(InstaCameraManager.CONNECT_TYPE_USB)
            true
        } catch (t: Throwable) {
            Log.e(TAG, "usb: openCamera threw", t)
            isConnectingUsb = false
            connectRequested = false
            false
        }
    }

    // ── Connect: Wi-Fi ────────────────────────────────────────────────────────────────────────

    /**
     * T4 — validate the joined SSID with the SDK's own matcher before binding/opening.
     *
     * Ports `ConnectViewModel.connectDeviceByWiFi()` (ConnectViewModel.kt:110-123): resolve the SSID
     * to a [CameraType] via [CameraWifiPrefix] (error 11001 if it is not a camera AP), gate on
     * `getSupportCameraType()` (error 11002), then bind + open. Using the SDK regex matters: the X4
     * Air's prefix is `"X4 Air "`, so a hand-rolled `startsWith("X4 ")` would reject it outright.
     */
    private fun beginWifiConnect(result: MethodChannel.Result) {
        val ssid = connectedWifiSsid()
        if (ssid != null) {
            val cameraType = CameraWifiPrefix.getCameraWifiPrefixByName(ssid)?.cameraTypeV2
            if (cameraType == null || cameraType == CameraType.UNKNOWN) {
                // Not a camera AP — almost always the phone silently back on the home router, which
                // used to bind us to the wrong network and fail ~15 s later with -214.
                Log.w(TAG, "wifi: SSID \"$ssid\" is not an Insta360 camera AP")
                failConnectImmediately(result, "wifi_not_camera", ERR_WIFI_NOT_CAMERA)
                return
            }
            if (!InstaCameraManager.getInstance().supportCameraType.contains(cameraType)) {
                Log.w(TAG, "wifi: camera type $cameraType is not supported by this SDK")
                failConnectImmediately(result, "camera_unsupported", ERR_CAMERA_UNSUPPORTED)
                return
            }
            Log.i(TAG, "wifi: SSID \"$ssid\" → $cameraType (supported)")
        } else {
            // SSID is unreadable (location permission denied / location services off → Android
            // returns "<unknown ssid>"). We cannot tell a camera AP from the home router, so we do
            // NOT reject — that would break a working Wi-Fi connect. Proceed as before and let the
            // SDK decide (a wrong network surfaces as -214, now with a human message).
            Log.w(TAG, "wifi: SSID unreadable (grant location to enable the camera-AP check)")
        }

        val camNet = findCameraWifiNetwork()
        if (camNet == null) {
            failConnectImmediately(result, "wifi_not_joined", ERR_WIFI_NOT_CAMERA)
            return
        }

        try {
            // The camera's AP has no internet, so the SDK can only reach it if we bind the process to
            // that network and hand its net id over (ConnectViewModel.kt:189-199, `bindNetwork()`).
            val mgr = InstaCameraManager.getInstance()
            mgr.setNetIdToCamera(camNet.networkHandle)
            connectivityManager.bindProcessToNetwork(camNet)
            wifiBound = true
            Log.i(TAG, "wifi: bound process to camera net ${camNet.networkHandle}")
            isConnectingWifi = true
            mgr.openCamera(InstaCameraManager.CONNECT_TYPE_WIFI)
            result.success(mapOf("status" to STATUS_CONNECTING))
        } catch (t: Throwable) {
            // T7 — a throw after the bind must never leave the app on an internet-less network.
            Log.e(TAG, "wifi: connect failed", t)
            isConnectingWifi = false
            connectRequested = false
            unbindCameraNetwork()
            result.error("connect_failed", t.message ?: connectErrorMessage(ERR_UNKNOWN), null)
        }
    }

    /** Re-issues the Wi-Fi open for a retry (the process is still bound from the first attempt). */
    private fun openWifiCamera(): Boolean {
        if (!connectRequested) return false
        return try {
            isConnectingWifi = true
            Log.i(TAG, "wifi: openCamera(CONNECT_TYPE_WIFI) attempt=${retryCount + 1}")
            InstaCameraManager.getInstance().openCamera(InstaCameraManager.CONNECT_TYPE_WIFI)
            true
        } catch (t: Throwable) {
            Log.e(TAG, "wifi: openCamera threw", t)
            isConnectingWifi = false
            connectRequested = false
            unbindCameraNetwork()
            false
        }
    }

    /** The joined Wi-Fi SSID, unquoted; null when Android will not tell us (`<unknown ssid>`). */
    @Suppress("DEPRECATION")
    private fun connectedWifiSsid(): String? {
        // Same source as the demo's `connectedWiFiSsid` (ext/SystemExt.kt:11-20).
        val raw = try {
            wifiManager.connectionInfo?.ssid
        } catch (t: Throwable) {
            null
        } ?: return null
        val ssid = raw.trim().removeSurrounding("\"")
        // "<unknown ssid>" (WifiManager.UNKNOWN_SSID) is what Android returns without location
        // permission / with location services off.
        if (ssid.isEmpty() || ssid == "<unknown ssid>" || ssid == "0x") return null
        return ssid
    }

    // ── Failure handling ──────────────────────────────────────────────────────────────────────

    /** A pre-flight rejection: nothing was opened or bound, so answer the MethodChannel directly. */
    private fun failConnectImmediately(result: MethodChannel.Result, code: String, errorCode: Int) {
        connectRequested = false
        isConnectingUsb = false
        isConnectingWifi = false
        result.error(code, connectErrorMessage(errorCode), mapOf("code" to errorCode))
    }

    /** A failure that arrives asynchronously (after `connect` already returned): report on the event channel. */
    private fun failConnect(errorCode: Int) {
        connectRequested = false
        isConnectingUsb = false
        isConnectingWifi = false
        unbindCameraNetwork()
        emitConnectError(errorCode)
    }

    private fun emitConnectError(errorCode: Int) {
        val message = connectErrorMessage(errorCode)
        // Raw code stays in the log for diagnostics; the UI gets the human text (T3).
        Log.e(TAG, "connect error $errorCode — $message")
        send("error", mapOf("scope" to "connect", "code" to errorCode, "message" to message))
    }

    /**
     * Release the camera-network binding. Unconditional and idempotent: `bindProcessToNetwork(null)`
     * is a no-op when nothing is bound, and being *too* eager here is always safer than leaving the
     * app stranded on the camera's internet-less AP (AC7).
     */
    private fun unbindCameraNetwork() {
        try {
            connectivityManager.bindProcessToNetwork(null)
            if (wifiBound) Log.i(TAG, "wifi: unbound process from camera net")
        } catch (t: Throwable) {
            Log.e(TAG, "unbind error", t)
        } finally {
            wifiBound = false
        }
    }

    private fun cameraConnectedType(): Int = try {
        InstaCameraManager.getInstance().cameraConnectedType
    } catch (t: Throwable) {
        InstaCameraManager.CONNECT_TYPE_NONE
    }

    private fun ensureCameraCallback() {
        if (cameraCallbackRegistered) return
        InstaCameraManager.getInstance().registerCameraChangedCallback(object : ICameraChangedCallback {
            override fun onCameraStatusChanged(enabled: Boolean, connectType: Int) {
                if (!enabled) Insta360FrameSink.reset()
                if (enabled) {
                    connectRequested = false
                    isConnectingUsb = false
                    isConnectingWifi = false
                    retryCount = 0
                    // Keep the process bound to the camera Wi-Fi for the whole preview session — the
                    // preview video stream needs it (so there's no internet while the camera is
                    // active). We unbind on disconnect / on any failure path.
                } else if (!connectRequested) {
                    // AC7 — the session is gone and no attempt is in flight, so the binding must go
                    // too: nothing may leave the app on the camera's internet-less network.
                    unbindCameraNetwork()
                }
                send("connection", mapOf("connected" to enabled, "connectType" to connectType))
            }

            override fun onCameraConnectError(errorCode: Int) {
                val wasWifi = isConnectingWifi
                val wasUsb = isConnectingUsb
                isConnectingWifi = false
                isConnectingUsb = false

                // T6 — retry transient handshake failures with backoff. 4403 ("camera due to
                // occupied") is deliberately NOT retried: it needs a camera power-cycle and retrying
                // only re-occupies the camera. Nor is 4425 (low battery) or a permission denial.
                if (connectRequested && (wasWifi || wasUsb) &&
                    errorCode in RETRYABLE_ERRORS && retryCount < MAX_CONNECT_RETRIES
                ) {
                    retryCount++
                    val delayMs = RETRY_BACKOFF_MS * retryCount
                    Log.w(TAG, "connect error $errorCode — retry $retryCount/$MAX_CONNECT_RETRIES in ${delayMs}ms")
                    send(
                        "connectRetry",
                        mapOf("attempt" to retryCount, "code" to errorCode, "max" to MAX_CONNECT_RETRIES),
                    )
                    main.postDelayed({
                        if (!connectRequested || isConnected || isConnecting) return@postDelayed
                        if (wasWifi) openWifiCamera() else openUsbCamera()
                    }, delayMs)
                    return
                }

                connectRequested = false
                // T7 — a failed Wi-Fi attempt must not leave us bound to the camera network.
                unbindCameraNetwork()
                emitConnectError(errorCode)
            }
        })
        cameraCallbackRegistered = true
    }

    /**
     * Finds the [Network] for the camera's Wi-Fi AP — i.e. the currently-connected system Wi-Fi.
     * Matches the SDK demo's `NetworkManager.cameraNet`: the WIFI-transport network whose IP equals
     * the active connection's IP, with a fallback to the first WIFI network. Returns null if the
     * phone is not joined to any Wi-Fi (so the caller can prompt the user).
     *
     * The fallback is only safe because [beginWifiConnect] has already validated the joined SSID
     * against the SDK's [CameraWifiPrefix] matcher.
     */
    @Suppress("DEPRECATION")
    private fun findCameraWifiNetwork(): Network? {
        val networks = connectivityManager.allNetworks
        val connectedIp = wifiManager.connectionInfo?.ipAddress ?: 0
        // Prefer an exact IP match (robust if multiple networks are momentarily present).
        if (connectedIp != 0) {
            for (net in networks) {
                val caps = connectivityManager.getNetworkCapabilities(net) ?: continue
                if (!caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) continue
                val info = caps.transportInfo
                if (info is WifiInfo && info.ipAddress == connectedIp) return net
            }
        }
        // Fallback: only one Wi-Fi connects at a time, so the first WIFI network is the camera AP.
        return networks.firstOrNull {
            connectivityManager.getNetworkCapabilities(it)
                ?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
        }
    }

    private fun status(): Map<String, Any?> {
        val connectType = cameraConnectedType()
        return mapOf(
            "supported" to Insta360Support.isSupported,
            "connected" to (connectType != InstaCameraManager.CONNECT_TYPE_NONE),
            "connecting" to isConnecting,
            "connectType" to connectType,
            "streaming" to Insta360FrameSink.streamingEnabled,
        )
    }

    private fun send(event: String, extra: Map<String, Any?>) {
        main.post { events?.success(HashMap(extra).apply { put("event", event) }) }
    }

    private companion object {
        const val TAG = "Insta360Bridge"

        // `connect` results (Dart maps these to Insta360ConnectOutcome).
        const val STATUS_CONNECTING = "connecting"
        const val STATUS_AWAITING_USB_PERMISSION = "awaiting_usb_permission"
        const val STATUS_ALREADY_CONNECTED = "already_connected"
        const val STATUS_ALREADY_CONNECTING = "already_connecting"

        // SDK connect error codes (decompiled from sdkcamera/basecamera 1.10.1).
        /** `'CHECK_TYPE status timeout'` — the open handshake never completed (USB permission race). */
        const val ERR_CHECK_TYPE_TIMEOUT = 2002
        /** `'camera due to occupied'` — stale session on the camera; only a power-cycle clears it. */
        const val ERR_CAMERA_OCCUPIED = 4403
        /** `'CHECK_TYPE status connect_low_battery'`. */
        const val ERR_LOW_BATTERY = 4425
        /** `OneDriverInfo$Notification$UsbError.ERR_SOCKET_CONNECT` — camera socket unreachable. */
        const val ERR_SOCKET_CONNECT = -214
        /** `appusb.UsbError.ERR_PERMISSION`. */
        const val ERR_USB_PERMISSION = -900001

        // Our own pre-flight codes, matching the demo's semantics (ConnectViewModel.kt:38-39).
        const val ERR_WIFI_NOT_CAMERA = 11001
        const val ERR_CAMERA_UNSUPPORTED = 11002
        const val ERR_UNKNOWN = 0

        /**
         * T6 — only genuinely transient handshake failures are retried. **4403 is excluded on
         * purpose**: it means the camera is occupied and needs a power-cycle, and retrying it just
         * re-occupies the camera. 4425 (low battery) and -900001 (permission denied) are equally
         * pointless to retry.
         */
        val RETRYABLE_ERRORS = setOf(ERR_CHECK_TYPE_TIMEOUT, ERR_SOCKET_CONNECT)
        const val MAX_CONNECT_RETRIES = 2
        const val RETRY_BACKOFF_MS = 1500L

        /**
         * T3 — SDK error code → cause + remedy the user can actually act on. The raw code is kept in
         * logcat; this is what the UI shows.
         */
        fun connectErrorMessage(code: Int): String = when (code) {
            ERR_CHECK_TYPE_TIMEOUT ->
                "Camera didn't respond. Accept the USB permission prompt, or unplug and re-plug the camera."
            ERR_CAMERA_OCCUPIED ->
                "Camera is busy. Please power-cycle the camera (turn it off and on), then try again."
            ERR_LOW_BATTERY ->
                "Camera battery is low. Charge the camera and retry."
            ERR_SOCKET_CONNECT ->
                "Phone isn't on the camera's Wi-Fi network. Join it in Android Settings, then retry."
            ERR_USB_PERMISSION ->
                "USB permission was denied. Allow access to the camera and retry."
            ERR_WIFI_NOT_CAMERA ->
                // T5 — model-accurate: the camera's own SSID prefix, e.g. "X4 Air 001ABC.OSC" on an
                // X4 Air, "X4 001ABC.OSC" on an X4. (Validated with the SDK's CameraWifiPrefix regex,
                // not a hardcoded prefix.)
                "Join your camera's Wi-Fi network in Android Settings — it is named after the camera, " +
                    "e.g. \"X4 Air 001ABC.OSC\" (X4 Air) or \"X4 001ABC.OSC\" (X4) — then try again."
            ERR_CAMERA_UNSUPPORTED ->
                "This camera model isn't supported. Use an Insta360 X3, X4, X4 Air or X5."
            // 44xx is the camera-reported CHECK_TYPE status family; anything else in it is a refusal
            // by the camera itself, and a power-cycle is the reliable remedy.
            in 4400..4499 ->
                "The camera refused the connection (status $code). Power-cycle the camera (turn it off " +
                    "and on) and try again."
            else ->
                "Couldn't connect to the 360 camera (error $code). Check the camera is on, power-cycle " +
                    "it, and check the USB cable or that you've joined its Wi-Fi, then try again."
        }
    }
}
