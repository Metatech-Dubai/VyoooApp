# VITURE XR Viewer — Setup & Build Guide

Head-tracked, monoscopic 360° viewing of a live Vyooo stream on **VITURE Luma XR** glasses.

A viewer wears the glasses (USB-C, DisplayPort Alt Mode), and turning their head rotates the view of
the host's live **monoscopic equirectangular (ERP)** 360 stream, shown on the glasses. This is **3DoF,
monoscopic** — the same image goes to both eyes (`set3D(false)`); there is no stereo depth (see
[Future work](#future-work)).

> **Status:** correct-by-construction scaffold. It compiles only once the proprietary VITURE AAR is in
> place and has never run on hardware. Every unverified SDK/USB/graphics detail is marked
> `// TODO(hardware): verify` in the code. See [Gaps & Risks](#gaps--risks).

---

## 1. Architecture

```
 Host (Insta360 → Agora)                 Viewer phone + VITURE glasses
 ───────────────────────                 ─────────────────────────────────────────────
                          Agora RTC
  live ERP video  ───────────────────▶  RtcEngine (audience)
                                          │
                                          │  VideoFrameObserver.onRenderVideoFrame  (Dart)
                                          ▼
                                   ViewerSphereView (Dart widget)
                                          │  MethodChannel vyooo/viewer_sphere: submitFrame (I420)
                                          ▼
                                   ViewerSphereBridge (Kotlin)
                                          │
                                          ▼
                                   ViewerSphereView (PlatformView)  ── hosts ──▶ ViewerSphereRenderer
                                          ▲                                        (GL ES 2.0 sphere,
                                          │ reads head pose each frame              ERP-on-sphere +
                                          │                                         I420→RGB shader)
   VITURE glasses  ── USB IMU ──▶  VitureManager (ArCallback.onImu, ~120 Hz, 3DoF)
                                          │   quaternion → MVP view matrix
                                          ▼
                                   Fullscreen GL surface ── DP Alt Mode (mirror) ──▶ glasses displays
```

- **Video path:** Agora remote ERP frames → Dart `VideoFrameObserver` → pushed as I420 to the native
  renderer → uploaded as three GL textures (Y/U/V) → sampled on a UV-sphere and converted to RGB in
  one fragment-shader pass.
- **Head path:** VITURE IMU → `ArCallback.onImu` → parsed to a unit quaternion in `VitureManager` →
  read directly on the GL render thread each frame → becomes the sphere's view (camera) rotation. The
  render loop redraws at a ~120 Hz cadence so the view stays locked to the head between (slower) video
  frames.
- **Output:** the sphere renders fullscreen on the phone; with DP Alt Mode the glasses **mirror** that
  surface. (True per-eye output to the external display is future work.)

### Channel / platform-view names (must match native ↔ Dart)

| Purpose | Type | Name |
|---|---|---|
| VITURE control | MethodChannel | `vyooo/viture` |
| VITURE events (connection / orientation) | EventChannel | `vyooo/viture/events` |
| Sphere frame + orientation ingress | MethodChannel | `vyooo/viewer_sphere` |
| Sphere GL surface | PlatformView (`AndroidView`) | `vyooo/viewer_sphere` |

### Files

**Kotlin — VITURE** (`android/app/src/main/kotlin/com/vyooo/viture/`)
- `VitureManager.kt` — wraps `com.viture.sdk.ArManager`; parses `onImu` → quaternion/Euler; publishes
  the pose to the renderer (native) and, throttled, to Flutter.
- `VitureUsbManager.kt` — USB attach/permission pre-flight (mirrors `Insta360UsbManager`).
- `VitureBridge.kt` — `vyooo/viture` control + `vyooo/viture/events`.

**Kotlin — viewer sphere** (`android/app/src/main/kotlin/com/vyooo/viewer/`)
- `ViewerSphereRenderer.kt` — GL ES 2.0 UV-sphere, ERP/I420 sampler shader, head-pose MVP.
- `ViewerSphereView.kt` + `ViewerSphereViewFactory.kt` — PlatformView hosting the GL surface.
- `ViewerSphereBridge.kt` — `vyooo/viewer_sphere` frame + orientation ingress.

**Kotlin — wiring**
- `MainActivity.kt` — registers `VitureBridge`, `ViewerSphereBridge`, and the `vyooo/viewer_sphere`
  view factory.
- `VyoooApplication.kt` — registers the VITURE USB receiver at startup.

**Dart** (`lib/`)
- `core/services/viture_service.dart` — channels to `vyooo/viture` (mirrors `insta360_live_service`).
- `widgets/viewer_sphere_view.dart` — hosts `vyooo/viewer_sphere`, owns the Agora frame observer +
  gyro fallback.
- `screens/content/live_stream_screen.dart` — XR-mode branch in `_buildVideoBackground()` + enter/exit
  affordance.

**Config**
- `android/app/build.gradle.kts` — `fileTree` for local AARs.
- `android/app/src/main/res/xml/device_filter.xml` — VITURE VID/PID (placeholder).
- `android/app/libs/{.gitignore,README.md}` — where the AAR goes (uncommitted).

---

## 2. Obtaining & placing the VITURE AAR

1. Sign in at **https://www.viture.com/developer** and download the Android SDK.
2. Copy the AAR into `android/app/libs/`, e.g. `VITURE-SDK-1.0.6.aar` (exact name/version may differ).
3. Rebuild — `build.gradle.kts` links it via
   `implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.aar", "*.jar"))))`.

The AAR is **not** committed (proprietary + large); `android/app/libs/.gitignore` enforces that. Until
it is present, the `com.viture.sdk.*` imports won't resolve and the app won't compile — expected.

---

## 3. USB VID/PID (device filter)

`res/xml/device_filter.xml` currently lists a **placeholder** VITURE vendor id `0x35ca` with no product
id. To confirm the real values:

1. Attach the glasses to the phone.
2. `adb logcat -s VitureUsb` — every attached device logs `vid=0x… pid=0x…`.
3. Put the exact values in **both** `device_filter.xml` **and**
   `VitureUsbManager.KNOWN_VENDOR_IDS`, then remove the `TODO(hardware): confirm VID/PID` markers.

Even without a matching filter entry, the in-app pre-flight still requests USB permission, so connecting
can work — but the attach-time auto-grant (the "Open Vyooo?" dialog) is lost.

---

## 4. Phone requirements

- **DisplayPort Alt Mode over USB-C** — the phone's USB-C port must output DP Alt Mode for the glasses
  to receive video. Many mid-range phones do **not** support this; confirm on the target device.
- **USB host / OTG** — required for the IMU interface (`android.hardware.usb.host`, already declared).
- **Android 9+ (API 28)** — the VITURE SDK baseline. This project is at `minSdk = 29`, so **no bump is
  needed**.
- **GPU** — OpenGL ES 2.0 (universally available). The sphere is lightweight (64×128 grid).

---

## 5. On-device validation checklist

Run these in order; each depends on the previous.

1. **USB permission**
   - Attach glasses → the "Open Vyooo? / Allow access" dialog appears (once VID/PID matches).
   - `logcat -s VitureUsb`: `requesting USB permission…` then `permission granted=true`.
2. **IMU stream**
   - Enter XR. `logcat -s VitureManager`: `VITURE SDK initialised (mono 3DoF)` and no `init()` error.
   - `vyooo/viture/events` should emit `orientation` events (~30 Hz throttled) that change as you move
     your head.
3. **Orientation → sphere latency (motion-to-photon)**
   - Turn your head; the world should counter-rotate with no perceptible lag. Target < ~20 ms.
   - If it lags or stutters, check the render cadence and the frame-marshalling cost (Gaps & Risks).
4. **Frame delivery**
   - `logcat -s ViewerSphereRenderer`: `first sphere frame drawn (WxH)`; the ERP content is visible on
     the sphere (not black, not garbled colour).
   - Verify the seam and poles look right — if the image is upside-down or mirrored, adjust the V-flip
     / axis TODOs in `ViewerSphereRenderer`.
5. **DP Alt Mode output**
   - The glasses show the same fullscreen sphere as the phone (mirror). If the glasses stay black,
     DP Alt Mode is likely unsupported on that phone/cable.
6. **Yaw drift**
   - Hold still for 60 s; the view should not slowly rotate. Some 3DoF IMUs drift in yaw — if so, add a
     recenter control (a `clearViewOrientation` + native recenter, TODO) and note the drift rate.
7. **Colour correctness**
   - Confirm skin tones / greys are neutral. If tinted, the BT.601 limited-range coefficients or a
     full-range source mismatch is the cause — adjust the fragment shader.
8. **Exit / re-enter & unplug**
   - Exiting XR returns the flat Agora view; unplugging the glasses mid-session drops XR cleanly.

---

## 6. Gaps & Risks (need hardware to close)

| # | Item | Detail |
|---|---|---|
| 1 | **VITURE SDK API shapes** | `ArManager.init()` return contract, `setImuOn`/`set3D`/`release` names, and IMU event ids are coded to the documented API but unverified. All marked `// TODO(hardware): verify`. |
| 2 | **IMU payload layout** | Euler at 0/4/8, quaternion at 20/24/28/32 (len ≥ 36) assumed; **quaternion component order (x,y,z,w vs w,x,y,z)** and axis/handedness are unconfirmed. Wrong order/axes → the world spins the wrong way; fix in `ViewerSphereRenderer.computeViewMatrix` / `VitureManager`. |
| 3 | **USB VID/PID** | Placeholder `0x35ca`. Confirm and update `device_filter.xml` + `VitureUsbManager`. |
| 4 | **DP Alt Mode & mirroring** | Assumes the glasses mirror the phone surface. Per-eye output via a `Presentation` on the external display (and correct FOV/scale for the Luma optics) is **not** built. `VERTICAL_FOV_DEG` (60°) is a guess — match the real display FOV. |
| 5 | **Agora frame path / latency** | We use the Dart `registerVideoFrameObserver` and push I420 over a method channel (drop-stale coalesced). This is the version-stable, no-NDK choice, but marshalling full frames has a cost. **The lower-latency production path is a native `agora::media::IVideoFrameObserver`** (via the plugin's native engine handle) delivering frames straight to the GL texture with zero channel copies — recommended if motion-to-photon or CPU proves too high. |
| 6 | **Remote frame format** | Assumed I420 (Android default). If the negotiated remote format differs (RGBA `pixelBuffer`, texture), add that path in `ViewerSphereView._pump` / the renderer. |
| 7 | **Raw-frame delivery enablement** | Some agora_rtc_engine builds require extra setup for the Dart observer to actually receive remote frames; verify `onRenderVideoFrame` fires on hardware. |
| 8 | **Frame rotation** | `VideoFrame.rotation` is ignored; ERP is normally rotation 0. Verify. |
| 9 | **Yaw drift / recenter** | No recenter control yet (see checklist #6). |
| 10 | **Refresh pacing** | The render loop uses an ~8 ms Handler cadence, not true vsync. For precise 120 Hz on the glasses, drive from `Choreographer` / the external display's vsync. |

---

## Future work

- **Stereoscopic 3DoF** — render a left/right eye pair (`set3D(true)`, per-eye viewports/IPD) for depth.
  Deliberately out of scope here; the scaffold is monoscopic only.
- **Native Agora frame observer** — see Risk #5.
- **Per-eye `Presentation` output** with correct Luma FOV/lens correction — see Risk #4.
- **Recenter gesture** and drift compensation.
