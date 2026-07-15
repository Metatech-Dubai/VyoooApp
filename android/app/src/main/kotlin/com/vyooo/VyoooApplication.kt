package com.vyooo

import android.app.Application
import android.os.Build
import android.util.Log
import com.arashivision.sdkcamera.InstaCameraSDK
import com.arashivision.sdkmedia.InstaMediaSDK
import com.vyooo.insta360.Insta360UsbManager

/**
 * Application entry point.
 *
 * Replaces Flutter's default `${applicationName}` so the Insta360 camera + media SDKs can be
 * initialised once at process start (the SDK requires init in [Application.onCreate]).
 *
 * Initialisation is **guarded**: the Insta360 native libraries ship for arm64-v8a only and target
 * API 29+. On unsupported devices we skip init so the rest of the app (Agora live, Firebase, etc.)
 * keeps working — the Insta360 capture feature is then simply reported as unavailable.
 */
class VyoooApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        if (Insta360Support.isSupported) {
            try {
                InstaCameraSDK.init(this)
                InstaMediaSDK.init(this)
                // USB permission pre-flight (SDK demo: InstaApp → UsbMgr.init). Registers the
                // attach/detach receiver and pre-requests permission for an already-plugged camera,
                // so the grant is cached long before openCamera() runs — the missing grant is what
                // produces the intermittent 2002 ("CHECK_TYPE status timeout").
                Insta360UsbManager.init(this)
                Log.i(TAG, "Insta360 SDK initialised")
            } catch (t: Throwable) {
                // Never let SDK init crash app startup — degrade to "feature unavailable".
                Insta360Support.initError = t.message ?: t.javaClass.simpleName
                Log.e(TAG, "Insta360 SDK init failed; feature disabled", t)
            }
        } else {
            Log.i(TAG, "Insta360 SDK skipped (unsupported device: arm64=${Insta360Support.isArm64}, api=${Build.VERSION.SDK_INT})")
        }
    }

    private companion object {
        const val TAG = "VyoooApplication"
    }
}

/** Single source of truth for whether the Insta360 capture feature can run on this device. */
object Insta360Support {
    val isArm64: Boolean = Build.SUPPORTED_64_BIT_ABIS.any { it.equals("arm64-v8a", ignoreCase = true) }
    val isApiOk: Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q // API 29
    val isSupported: Boolean = isArm64 && isApiOk

    /** Set if SDK init threw; surfaced to Flutter for diagnostics. */
    @Volatile var initError: String? = null
}
