package com.vyooo.insta360

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Build
import android.util.Log

/**
 * USB permission pre-flight for the Insta360 camera.
 *
 * Ported from the SDK demo's `usb/UsbMgr.kt` (`SDKs/Android-SDK-V1.10.1/sdkdemo/app/src/main/java/
 * com/arashivision/sdk/demo/usb/UsbMgr.kt:52-97`), which registers a receiver for
 * `ACTION_USB_DEVICE_ATTACHED` / `ACTION_USB_DEVICE_DETACHED` / a private permission action and
 * requests permission for every already-attached device at start-up.
 *
 * Why this exists: `InstaCameraManager.openCamera(CONNECT_TYPE_USB)` does *not* wait for the USB
 * permission dialog. The dialog surfaces ~1 s into the SDK's OPENING state; if the user is slow (or
 * never sees it) the SDK's CHECK_TYPE handshake times out and reports **2002**. Once Android has
 * cached the grant the same code path "just works" — which is exactly why the failure looked
 * intermittent. We therefore hold `openCamera()` back until permission is in hand.
 *
 * We diverge from the demo in one respect: the demo requests permission for *every* attached device
 * and does nothing with the result. We need to know *which* device is the camera and whether the
 * grant landed, so we resolve a camera device (see [cameraDevice]) and expose a completion callback.
 */
@SuppressLint("StaticFieldLeak")
object Insta360UsbManager {

    /** Outcome of [preflight]. */
    enum class Preflight {
        /** Permission already held — the caller may call `openCamera()` immediately. */
        GRANTED,

        /** The system dialog is up; the caller's callbacks fire when the user answers. */
        REQUESTED,

        /** Nothing is plugged in — surface a "plug the camera in" message instead of a 2002. */
        NO_DEVICE,
    }

    private const val TAG = "Insta360Usb"
    private const val ACTION_USB_PERMISSION = "com.vyooo.insta360.USB_PERMISSION"

    /**
     * Vendor IDs from the SDK's own `res/xml/device_filter.xml` (sdkcamera-1.10.1).
     *
     * ⚠️ UNVERIFIED FOR THE X4 AIR — these are the only two vendor IDs the SDK ships and we have no
     * X4 Air to enumerate. If a client's camera reports a different vendor id it will still be
     * handled (see [cameraDevice]'s single-device fallback) and the real VID/PID is logged at
     * [Log.i] with tag `Insta360Usb` — collect it from the client device and add it here and in
     * `res/xml/device_filter.xml`.
     */
    private val KNOWN_VENDOR_IDS = intArrayOf(0x2e1a, 0x4255)

    private var appContext: Context? = null
    private var usbManager: UsbManager? = null

    /** Callbacks for the connect attempt currently waiting on the permission dialog. */
    private var onGranted: (() -> Unit)? = null
    private var onDenied: (() -> Unit)? = null

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                    val device = deviceOf(intent) ?: return
                    Log.i(TAG, "attached ${describe(device)}")
                    // Mirrors UsbMgr.kt:24-30 — ask as soon as it is plugged in, so the grant is
                    // already cached by the time the user taps "connect".
                    if (isCamera(device)) requestPermission(device)
                }

                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    val device = deviceOf(intent)
                    Log.i(TAG, "detached ${device?.let { describe(it) }}")
                    // A connect waiting on a dialog can never complete once the device is gone.
                    val denied = onDenied
                    clearCallbacks()
                    denied?.invoke()
                }

                ACTION_USB_PERMISSION -> synchronized(this) {
                    val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                    val device = deviceOf(intent)
                    Log.i(TAG, "permission granted=$granted for ${device?.let { describe(it) }}")
                    val g = onGranted
                    val d = onDenied
                    clearCallbacks()
                    if (granted) g?.invoke() else d?.invoke()
                }
            }
        }
    }

    /** Registers the USB receiver and pre-requests permission for anything already attached. */
    fun init(context: Context) {
        if (appContext != null) return
        val ctx = context.applicationContext
        appContext = ctx
        usbManager = ctx.getSystemService(Context.USB_SERVICE) as? UsbManager ?: return

        val filter = IntentFilter().apply {
            addAction(ACTION_USB_PERMISSION)
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ctx.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            ctx.registerReceiver(receiver, filter)
        }

        // UsbMgr.kt:67 / :71-84 — request for already-attached devices at start-up so the grant is
        // cached before the user ever reaches the camera picker.
        val camera = cameraDevice()
        if (camera != null && !hasPermission(camera)) requestPermission(camera)
    }

    /**
     * Ensures USB permission for the camera **before** `openCamera(CONNECT_TYPE_USB)` is called.
     *
     * Returns [Preflight.GRANTED] when permission is already held (connect synchronously),
     * [Preflight.REQUESTED] when the system dialog was raised (one of [onGranted]/[onDenied] fires
     * on the main looper thread), or [Preflight.NO_DEVICE] when nothing is plugged in.
     */
    fun preflight(onGranted: () -> Unit, onDenied: () -> Unit): Preflight {
        val mgr = usbManager ?: return Preflight.NO_DEVICE
        val device = cameraDevice() ?: return Preflight.NO_DEVICE
        if (mgr.hasPermission(device)) return Preflight.GRANTED
        this.onGranted = onGranted
        this.onDenied = onDenied
        requestPermission(device)
        return Preflight.REQUESTED
    }

    /** Drop any pending permission callbacks (e.g. the user cancelled the connect). */
    fun cancelPending() = clearCallbacks()

    /** All attached USB devices, described — for diagnostics/logs when a connect fails. */
    fun describeAttached(): String {
        val devices = usbManager?.deviceList?.values?.toList().orEmpty()
        return if (devices.isEmpty()) "<none>" else devices.joinToString { describe(it) }
    }

    /**
     * The attached device we believe is the camera.
     *
     * Preference order:
     *  1. a device whose vendor id is in [KNOWN_VENDOR_IDS] (the SDK's own filter);
     *  2. failing that, the single attached non-hub device — this is the fallback that keeps an
     *     **X4 Air with an unknown VID/PID** working, since we cannot verify it locally.
     */
    fun cameraDevice(): UsbDevice? {
        val devices = usbManager?.deviceList?.values?.toList().orEmpty()
        if (devices.isEmpty()) return null
        devices.firstOrNull { isCamera(it) }?.let { return it }
        val nonHubs = devices.filter { it.deviceClass != UsbConstants.USB_CLASS_HUB }
        return if (nonHubs.size == 1) {
            Log.w(TAG, "no known-VID camera; falling back to sole device ${describe(nonHubs[0])}")
            nonHubs[0]
        } else {
            Log.w(TAG, "cannot identify camera among: ${describeAttached()}")
            null
        }
    }

    private fun isCamera(device: UsbDevice): Boolean =
        KNOWN_VENDOR_IDS.any { it == device.vendorId }

    private fun hasPermission(device: UsbDevice): Boolean =
        usbManager?.hasPermission(device) == true

    private fun requestPermission(device: UsbDevice) {
        val ctx = appContext ?: return
        val mgr = usbManager ?: return
        if (mgr.hasPermission(device)) {
            val g = onGranted
            clearCallbacks()
            g?.invoke()
            return
        }
        // Explicit package: an implicit broadcast PendingIntent is not delivered on Android 14+.
        val intent = Intent(ACTION_USB_PERMISSION).setPackage(ctx.packageName)
        val pending = PendingIntent.getBroadcast(
            ctx, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        Log.i(TAG, "requesting USB permission for ${describe(device)}")
        mgr.requestPermission(device, pending)
    }

    private fun clearCallbacks() {
        onGranted = null
        onDenied = null
    }

    private fun deviceOf(intent: Intent): UsbDevice? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
        }

    /** VID/PID in hex — this is the string to collect from a client device for `device_filter.xml`. */
    private fun describe(d: UsbDevice): String =
        "${d.deviceName} vid=0x${Integer.toHexString(d.vendorId)} pid=0x${Integer.toHexString(d.productId)} " +
            "class=${d.deviceClass} product=${d.productName ?: "?"}"
}
