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
                val type = call.argument<String>("type") ?: "usb"
                try {
                    ensureCameraCallback()
                    if (type == "wifi") {
                        // The camera's Wi-Fi AP has no internet, so the SDK can only reach it if we
                        // bind the process to that network and hand its net id to the SDK. Mirrors the
                        // SDK demo's ConnectViewModel.bindNetwork(); requires the user to have joined
                        // the camera's Wi-Fi in Android settings first.
                        val camNet = findCameraWifiNetwork()
                        if (camNet == null) {
                            result.error(
                                "wifi_not_joined",
                                "Join the camera's Wi-Fi (e.g. \"X4 ……OSC\") in Android Settings, then try again.",
                                null,
                            )
                            return
                        }
                        val mgr = InstaCameraManager.getInstance()
                        mgr.setNetIdToCamera(camNet.networkHandle)
                        connectivityManager.bindProcessToNetwork(camNet)
                        Log.i(TAG, "wifi: bound process to camera net ${camNet.networkHandle}")
                        mgr.openCamera(InstaCameraManager.CONNECT_TYPE_WIFI)
                    } else {
                        InstaCameraManager.getInstance().openCamera(InstaCameraManager.CONNECT_TYPE_USB)
                    }
                    result.success(true)
                } catch (t: Throwable) {
                    Log.e(TAG, "connect failed", t)
                    result.error("connect_failed", t.message, null)
                }
            }

            "disconnect" -> {
                try {
                    InstaCameraManager.getInstance().closeCamera()
                } catch (t: Throwable) {
                    Log.e(TAG, "disconnect error", t)
                }
                // Release the camera-network binding so the rest of the app regains normal routing.
                try {
                    connectivityManager.bindProcessToNetwork(null)
                } catch (t: Throwable) {
                    Log.e(TAG, "unbind error", t)
                }
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

    private fun ensureCameraCallback() {
        if (cameraCallbackRegistered) return
        InstaCameraManager.getInstance().registerCameraChangedCallback(object : ICameraChangedCallback {
            override fun onCameraStatusChanged(enabled: Boolean, connectType: Int) {
                if (!enabled) Insta360FrameSink.reset()
                // Keep the process bound to the camera Wi-Fi for the whole preview session — the
                // preview video stream needs it (so there's no internet while the camera is active).
                // We unbind only on disconnect (see the "disconnect" handler).
                send("connection", mapOf("connected" to enabled, "connectType" to connectType))
            }

            override fun onCameraConnectError(errorCode: Int) {
                send("error", mapOf("scope" to "connect", "code" to errorCode))
            }
        })
        cameraCallbackRegistered = true
    }

    /**
     * Finds the [Network] for the camera's Wi-Fi AP — i.e. the currently-connected system Wi-Fi.
     * Matches the SDK demo's `NetworkManager.cameraNet`: the WIFI-transport network whose IP equals
     * the active connection's IP, with a fallback to the first WIFI network. Returns null if the
     * phone is not joined to any Wi-Fi (so the caller can prompt the user).
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
        val connectType = try {
            InstaCameraManager.getInstance().cameraConnectedType
        } catch (t: Throwable) {
            InstaCameraManager.CONNECT_TYPE_NONE
        }
        return mapOf(
            "supported" to Insta360Support.isSupported,
            "connected" to (connectType != InstaCameraManager.CONNECT_TYPE_NONE),
            "connectType" to connectType,
            "streaming" to Insta360FrameSink.streamingEnabled,
        )
    }

    private fun send(event: String, extra: Map<String, Any?>) {
        main.post { events?.success(HashMap(extra).apply { put("event", event) }) }
    }

    private companion object {
        const val TAG = "Insta360Bridge"
    }
}
