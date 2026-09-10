package com.vyooo.viewer

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel `vyooo/viewer_sphere` — the ingress for the two Dart-supplied inputs to the sphere:
 *
 *  - `submitFrame`  — one remote ERP frame as **I420** (Y/U/V byte arrays + dimensions + strides),
 *                     pushed from the Agora video-frame observer (see the Dart `ViewerSphereView`).
 *  - `setViewOrientation` / `clearViewOrientation` — the touch/gyro fallback override (degrees).
 *
 * See the build guide for *why* the Agora frame path is done in Dart (registerVideoFrameObserver) and
 * pushed here, rather than via a native `IVideoFrameObserver`. The Dart side already coalesces to the
 * latest frame (drop-stale) so this channel is never flooded — the same lesson as the Insta360 frame
 * channel, which OOM-crashed when every ~MB frame was posted unbounded.
 */
class ViewerSphereBridge(messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {

    private val methodChannel = MethodChannel(messenger, CHANNEL)

    init {
        methodChannel.setMethodCallHandler(this)
    }

    fun dispose() {
        methodChannel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "submitFrame" -> {
                val y = call.argument<ByteArray>("y")
                val u = call.argument<ByteArray>("u")
                val v = call.argument<ByteArray>("v")
                val width = call.argument<Int>("width") ?: 0
                val height = call.argument<Int>("height") ?: 0
                val yStride = call.argument<Int>("yStride") ?: width
                val uStride = call.argument<Int>("uStride") ?: (width / 2)
                val vStride = call.argument<Int>("vStride") ?: (width / 2)
                if (y != null && u != null && v != null && width > 0 && height > 0) {
                    ViewerSphereView.submitYuv(y, u, v, width, height, yStride, uStride, vStride)
                }
                result.success(null)
            }

            "setViewOrientation" -> {
                val yaw = (call.argument<Double>("yaw") ?: 0.0).toFloat()
                val pitch = (call.argument<Double>("pitch") ?: 0.0).toFloat()
                ViewerSphereView.setExternalOrientation(yaw, pitch)
                result.success(null)
            }

            "clearViewOrientation" -> {
                ViewerSphereView.clearExternalOrientation()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private companion object {
        const val CHANNEL = "vyooo/viewer_sphere"
    }
}
