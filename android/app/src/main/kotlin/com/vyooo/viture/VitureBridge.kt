package com.vyooo.viture

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Native bridge for the VITURE XR viewer feature.
 *
 *  - MethodChannel `vyooo/viture`        — control (isSupported / start / stop / isConnected /
 *                                          setImuEnabled / getStatus)
 *  - EventChannel  `vyooo/viture/events` — connection state, SDK events, and throttled head
 *                                          orientation (Euler degrees, for a HUD/debug readout)
 *
 * The head-tracked render is driven **natively** for latency: [VitureManager] publishes the latest
 * orientation quaternion, which [com.vyooo.viewer.ViewerSphereRenderer] reads directly on its GL
 * thread. This bridge only mirrors state/telemetry to Flutter — it is never in the motion-to-photon
 * path.
 */
class VitureBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val main = Handler(Looper.getMainLooper())
    private val methodChannel = MethodChannel(messenger, CHANNEL_METHOD)
    private val eventChannel = EventChannel(messenger, CHANNEL_EVENTS)

    private var events: EventChannel.EventSink? = null

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                events = sink
                VitureManager.onConnectionChanged = { connected ->
                    send("connection", mapOf("connected" to connected))
                }
                VitureManager.onEvent = { id ->
                    send("sdkEvent", mapOf("id" to id))
                }
                VitureManager.onOrientation = { yaw, pitch, roll ->
                    send("orientation", mapOf("yaw" to yaw, "pitch" to pitch, "roll" to roll))
                }
            }

            override fun onCancel(arguments: Any?) {
                events = null
                VitureManager.onConnectionChanged = null
                VitureManager.onEvent = null
                VitureManager.onOrientation = null
            }
        })
    }

    fun dispose() {
        VitureUsbManager.cancelPending()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        VitureManager.onConnectionChanged = null
        VitureManager.onEvent = null
        VitureManager.onOrientation = null
        events = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // Device *capability* gate (min API 28 for the SDK). Real availability is only known once
            // [start] succeeds (the AAR may be absent / no glasses attached).
            "isSupported" -> result.success(isSupported)

            "start" -> startWithUsbPreflight(result)

            "stop" -> {
                VitureUsbManager.cancelPending()
                VitureManager.stop()
                result.success(null)
            }

            "isConnected" -> result.success(VitureManager.isInitialized)

            "setImuEnabled" -> {
                VitureManager.setImuEnabled(call.argument<Boolean>("enabled") ?: true)
                result.success(null)
            }

            "getStatus" -> result.success(
                mapOf(
                    "supported" to isSupported,
                    "connected" to VitureManager.isInitialized,
                    "imuEnabled" to VitureManager.isImuEnabled,
                ),
            )

            else -> result.notImplemented()
        }
    }

    /**
     * Ensure USB permission for the glasses' IMU endpoint, then start the SDK.
     *
     * Mirrors the Insta360 connect flow: the SDK does not wait for the Android USB permission dialog,
     * so we hold [VitureManager.start] until the grant is in hand (or fail cleanly if nothing is
     * plugged in). DP-Alt-Mode video output needs no permission — this is purely for the IMU.
     */
    private fun startWithUsbPreflight(result: MethodChannel.Result) {
        if (!isSupported) {
            result.error("unsupported", "VITURE XR unavailable on this device (needs Android 9+).", null)
            return
        }
        val preflight = try {
            VitureUsbManager.preflight(
                onGranted = { main.post { doStart(null) } },
                onDenied = { main.post { failStart("usb_permission", "USB permission denied for the glasses.") } },
            )
        } catch (t: Throwable) {
            Log.e(TAG, "usb preflight failed", t)
            VitureUsbManager.Preflight.GRANTED // never block start on our own pre-flight
        }

        when (preflight) {
            VitureUsbManager.Preflight.NO_DEVICE -> {
                // Not necessarily fatal: on some phones the glasses present only as a DP display and
                // the IMU interface is claimed by the SDK without appearing in UsbManager's device
                // list. Attempt the start anyway; the SDK reports the real outcome. // TODO(hardware): verify
                Log.w(TAG, "usb: no glasses in device list; attempting start anyway (${VitureUsbManager.describeAttached()})")
                doStart(mapOf("note" to "no_usb_device_listed"))
            }
            VitureUsbManager.Preflight.REQUESTED -> {
                Log.i(TAG, "usb: awaiting permission before SDK start")
                result.success(mapOf("status" to "awaiting_usb_permission"))
            }
            VitureUsbManager.Preflight.GRANTED -> {
                val ok = VitureManager.start(context)
                if (ok) result.success(mapOf("status" to "started"))
                else result.error("start_failed", "VITURE SDK failed to initialise (AAR present? glasses attached?).", null)
            }
        }
    }

    /** Async start after a granted USB dialog (the MethodChannel result already returned). */
    private fun doStart(extra: Map<String, Any?>?) {
        val ok = VitureManager.start(context)
        send("startResult", HashMap<String, Any?>().apply {
            put("ok", ok)
            extra?.let { putAll(it) }
        })
    }

    private fun failStart(code: String, message: String) {
        Log.e(TAG, "start failed: $code — $message")
        send("error", mapOf("code" to code, "message" to message))
    }

    private fun send(event: String, extra: Map<String, Any?>) {
        main.post { events?.success(HashMap(extra).apply { put("event", event) }) }
    }

    private companion object {
        const val TAG = "VitureBridge"
        const val CHANNEL_METHOD = "vyooo/viture"
        const val CHANNEL_EVENTS = "vyooo/viture/events"

        /** VITURE SDK targets Android API 28+. */
        val isSupported: Boolean get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P
    }
}
