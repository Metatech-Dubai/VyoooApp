package com.vyooo.viture

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
 * USB attach / permission pre-flight for the VITURE Luma XR glasses.
 *
 * Mirrors [com.vyooo.insta360.Insta360UsbManager] (same design, same rationale). The glasses connect
 * over USB-C: the *video* travels as a DisplayPort Alt-Mode display (handled by Android's display
 * subsystem, no app permission needed), while the *IMU* is read by the VITURE SDK over a USB
 * interface — and Android gates access to that interface behind a runtime USB permission. Requesting
 * it up-front (at attach, and again just before [VitureManager.start]) avoids the SDK failing to open
 * its IMU endpoint because the grant is not yet cached.
 *
 * ⚠️ The VITURE USB VID/PID below is a **PLACEHOLDER**. Confirm the real values on hardware (logcat
 * tag `VitureUsb` prints `vid=0x… pid=0x…` for every attached device) and update both [KNOWN_VENDOR_IDS]
 * here and `res/xml/device_filter.xml`.
 */
@SuppressLint("StaticFieldLeak")
object VitureUsbManager {

    /** Outcome of [preflight] (identical semantics to the Insta360 pre-flight). */
    enum class Preflight { GRANTED, REQUESTED, NO_DEVICE }

    private const val TAG = "VitureUsb"
    private const val ACTION_USB_PERMISSION = "com.vyooo.viture.USB_PERMISSION"

    /**
     * VITURE USB vendor id(s). // TODO(hardware): confirm VID/PID — placeholder only.
     *
     * 0x35CA is VITURE's published USB-IF vendor id per public reports, but it is UNVERIFIED here and
     * the Luma XR product id is unknown. If a device enumerates with a different vendor id it is still
     * handled by [glassesDevice]'s single-device fallback, and the real value is logged at [Log.i].
     */
    private val KNOWN_VENDOR_IDS = intArrayOf(0x35CA) // TODO(hardware): confirm VID/PID

    private var appContext: Context? = null
    private var usbManager: UsbManager? = null

    private var onGranted: (() -> Unit)? = null
    private var onDenied: (() -> Unit)? = null

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                    val device = deviceOf(intent) ?: return
                    Log.i(TAG, "attached ${describe(device)}")
                    if (isGlasses(device)) requestPermission(device)
                }

                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    val device = deviceOf(intent)
                    Log.i(TAG, "detached ${device?.let { describe(it) }}")
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

    /** Register the USB receiver and pre-request permission for anything already attached. */
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

        val glasses = glassesDevice()
        if (glasses != null && !hasPermission(glasses)) requestPermission(glasses)
    }

    /**
     * Ensure USB permission for the glasses **before** [VitureManager.start] opens the IMU endpoint.
     * Returns [Preflight.GRANTED] (open synchronously), [Preflight.REQUESTED] (a callback fires when
     * the user answers the dialog) or [Preflight.NO_DEVICE] (nothing plugged in).
     */
    fun preflight(onGranted: () -> Unit, onDenied: () -> Unit): Preflight {
        val mgr = usbManager ?: return Preflight.NO_DEVICE
        val device = glassesDevice() ?: return Preflight.NO_DEVICE
        if (mgr.hasPermission(device)) return Preflight.GRANTED
        this.onGranted = onGranted
        this.onDenied = onDenied
        requestPermission(device)
        return Preflight.REQUESTED
    }

    fun cancelPending() = clearCallbacks()

    fun describeAttached(): String {
        val devices = usbManager?.deviceList?.values?.toList().orEmpty()
        return if (devices.isEmpty()) "<none>" else devices.joinToString { describe(it) }
    }

    /**
     * The attached device we believe is the glasses. Preference: a known VITURE vendor id, else the
     * single attached non-hub device (keeps an unverified VID/PID working). Note the glasses may
     * additionally present as a DisplayPort display — that path is invisible to [UsbManager].
     */
    fun glassesDevice(): UsbDevice? {
        val devices = usbManager?.deviceList?.values?.toList().orEmpty()
        if (devices.isEmpty()) return null
        devices.firstOrNull { isGlasses(it) }?.let { return it }
        val nonHubs = devices.filter { it.deviceClass != UsbConstants.USB_CLASS_HUB }
        return if (nonHubs.size == 1) {
            Log.w(TAG, "no known-VID glasses; falling back to sole device ${describe(nonHubs[0])}")
            nonHubs[0]
        } else {
            Log.w(TAG, "cannot identify glasses among: ${describeAttached()}")
            null
        }
    }

    private fun isGlasses(device: UsbDevice): Boolean =
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

    /** VID/PID in hex — collect this from a device to fill in `device_filter.xml`. */
    private fun describe(d: UsbDevice): String =
        "${d.deviceName} vid=0x${Integer.toHexString(d.vendorId)} pid=0x${Integer.toHexString(d.productId)} " +
            "class=${d.deviceClass} product=${d.productName ?: "?"}"
}
