# iOS SDK Integration — Setup & Build Guide (Insta360 1.9.2)

> Note: this guide was requested at `../Technical documentation/`, but this branch was authored in an
> isolated git worktree that cannot write outside the repo. It lives in `docs/` so it is committed
> with the branch — copy/move it to `Technical documentation/` if you keep docs there.

Status: native iOS integration written on Linux (no compiler available). This guide covers what was
wired up, the **Mac finish/build** procedure, and a **gaps/risks** list of everything that must be
verified on a Mac + real camera.

Branch: `src/ios-sdk-integration` (off `origin/src/optimization-pipeline`).

---

## 1. What the SDK is

Unpacked at `../SDKs/iOS-SDK-1.9.2/iOS_v1.9.2/INSCameraSDKSample-bluetooth/`. It ships three
**dynamic** `xcframework`s (device `ios-arm64` + `ios-arm64-simulator` slices; INSCoreMedia also has
watchOS slices and large dSYMs):

| Framework | arm64 size | Role |
|---|---|---|
| `INSCameraSDK.xcframework` | ~6 MB | Camera control, media session, preview player, flat-pano/raw outputs |
| `INSCameraServiceSDK.xcframework` | ~24 MB | `INSCameraManager` (usb/socket/shared), connection state + notifications, commands |
| `INSCoreMedia.xcframework` | ~116 MB binary (+759 MB dSYM) | Rendering (`INSRenderView`), stitching, gyro, filters — dependency of the above |

The SDK also bundles Eureka / SnapKit / SSZipArchive — those are **sample-app UI only** and are NOT
needed by our integration.

### Key API (what the bridge actually uses)

- **Connection** — `INSCameraManager` (from `INSCameraServiceSDK`):
  - `+usbManager` / `+socketManager` / `+sharedManager` singletons; call `setup()` to start, `shutdown()` to stop.
  - USB (Lightning/MFi) cameras are detected by `usbManager` via the **External Accessory** framework + the `UISupportedExternalAccessoryProtocols` Info.plist array. **No runtime USB permission dialog** (unlike Android).
  - Wi-Fi via `socketManager().setup()` → connects to the camera AP at `http://192.168.42.1` (Lightning proxy is `http://localhost:9099`).
  - Outcome is asynchronous, delivered as `NSNotificationCenter.default` notifications:
    `INSCameraDidConnectNotification`, `INSCameraDidDisconnectNotification`,
    `INSCameraConnectionErrorNotification`, `INSCameraDidReconnectNotification`.
    `cameraState` (`INSCameraState`) is KVO-observable; `.connected` = ready.
- **Preview + frames** — `INSCameraMediaSession` (AVFoundation-like):
  - Configure `expectedVideoResolution` / `expectedAudioSampleRate`, `plug`/`unplug` pluggables, `startRunning`/`stopRunning`/`commitChanges`.
  - `INSCameraPreviewPlayer(renderView:)` renders the interactive sphere into an `INSRenderView(frame:renderType: .sphericalPanoRender)`.
  - `INSCameraFlatPanoOutput(outputWidth:outputHeight:)` stitches the feed to a flat **ERP** frame; set `outputPixelFormat = kCVPixelFormatType_32BGRA`; the `INSCameraAVOutputDelegate.avOutput(_:didOutputVideoFrame:)` callback delivers an `INSCameraVideoFrame` carrying a `CVPixelBufferRef` + timestamp.
- **Setup** — the README requires `[[INSCameraManager sharedManager] setup]` at app launch.

---

## 2. The Dart contract we mirrored (unchanged)

`lib/core/services/insta360_live_service.dart` — identical channels/methods/events on both platforms:

- MethodChannel `vyooo/insta360`: `isSupported`, `connect{type:'wifi'|'usb'}`, `disconnect`,
  `setFrameStreaming{enabled}`, `getStatus`, `getPipelineMetrics`, `createProcessedTexture`,
  `disposeProcessedTexture`, `setMaskEnabled`, `setTemporalEnabled`, `setAiEnabled`,
  `setViewOrientation{yaw,pitch}`.
- `connect` returns `{status: connecting | awaiting_usb_permission | already_connected | already_connecting}` or throws (mapped to `failed`).
- EventChannel `vyooo/insta360/events`: `connection{connected,connectType}`, `previewState{state:'warming'|'ready'}`, `frameStats{width,height,fps,count}`, `error{scope,code,message}`, `connectRetry{...}`.
- EventChannel `vyooo/insta360/frames`: `{bytes:RGBA, width, height, ptsUs}`.
- PlatformView `vyooo/insta360_preview` (creationParams `{width,height}` = ERP extract size, default 1920×960).

---

## 3. What was wired up (committed on this branch)

### Native Swift bridge — `ios/Runner/Insta360/`
- **`Insta360Support.swift`** — device-support gate (arm64 **device**, iOS 15+; simulator disabled) + one-time `setup()` of the shared+usb managers. Mirrors Android `Insta360Support` + `VyoooApplication.onCreate`.
- **`Insta360Bridge.swift`** — the MethodChannel + both EventChannels. Translates the iOS notification-based connection model into the same `connection`/`error` events; single-slot coalescing frame dispatch (bounds memory like Android); USB pre-flight via `EAAccessoryManager` (→ `usb_no_device`); pipeline toggles stored; `getStatus`/`getPipelineMetrics`.
- **`Insta360FrameSink.swift`** — BGRA `CVPixelBuffer` → tightly-packed RGBA, **runs the full pipeline** (see §4b), then fans the processed frame to the host texture (BGRA) + transmit (RGBA, 24 fps cap); fps/stats; real `getPipelineMetrics`. Mirror of Android `Insta360FrameSink`.
- **`Insta360/Pipeline/`** (11 files) — the ported optimisation pipeline: `FramePipeline`, `FrameStage`, `PipelineFrame`(+`FrameMeta`), `PipelineHints`, `PipelineMetrics`, the five stages, `HeuristicDecisionLayer`, and the iOS-only `PixelBufferFactory`. Parity table in §4b.
- **`Insta360ProcessedTexture.swift`** — `FlutterTexture` backing `createProcessedTexture()` (host preview of the **processed** ERP via a `Texture` widget). iOS analogue of Android `Insta360GlRenderer`.
- **`Insta360PreviewView.swift`** (+ factory) — `FlutterPlatformView` hosting `INSRenderView` + media session + preview player + flat-pano output; emits `previewState`; native pan/pinch look-around (touches reach a UiKitView on iOS, unlike the Android GL SurfaceView).

### Registration
- **`ios/Runner/AppDelegate.swift`** — `Insta360Support.setupIfSupported()`, constructs `Insta360Bridge`, registers the `vyooo/insta360_preview` platform-view factory (under a plugin registrar named `Insta360`).

### Dart
- **`lib/widgets/insta360_preview_view.dart`** — added an **iOS `UiKitView`** branch (was hard-gated to Android) so the native preview is reachable. Android path unchanged. The `Texture`-based processed view and the whole method-channel API were already platform-agnostic.

### Vendoring (see §4) — `ios/Frameworks/` + Podfile + `ios/scripts/install_insta360_sdk.sh`
### Xcode project — `ios/Runner.xcodeproj/project.pbxproj` hand-edited to add the 5 Swift files to the Runner target (build files, file refs, an `Insta360` group, and the Sources phase). **Verify in Xcode** (see §6).
### Info.plist — added `UISupportedExternalAccessoryProtocols`, `NSLocalNetworkUsageDescription`, `NSBluetoothAlwaysUsageDescription`, `NSAllowsLocalNetworking`, and `external-accessory` background mode.

---

## 4. Vendoring decision (and why)

**Decision: local CocoaPods pod that `vendored_frameworks` the three xcframeworks; binaries are NOT
committed to git.**

- All three frameworks are **dynamic** (`file` → "dynamically linked shared library"), so they must be
  embedded & code-signed. CocoaPods does that automatically for vendored dynamic frameworks — no
  manual Xcode "Embed & Sign", and no fragile `project.pbxproj` framework-embedding edits.
- **Why not commit the binaries:** device-only slices are ~150 MB; full xcframeworks with all slices +
  dSYMs are ~1.5 GB. The task explicitly says don't commit gigabytes. So `ios/Frameworks/.gitignore`
  ignores `*.xcframework/` and keeps only the podspec + README; a copy script stages the binaries on
  the Mac from the `../SDKs/...` source before `pod install`.
- **Why a pod, not a raw Xcode framework reference:** the Podfile already owns dependency wiring
  (`use_frameworks! :linkage => :static`); a `:path` pod is idiomatic and keeps embed/sign automatic.
  Vendored **dynamic** frameworks embed correctly even under `:linkage => :static` (that setting only
  affects pods built from source).

Files:
- `ios/Frameworks/INSCameraSDK.podspec` — `vendored_frameworks` = the 3 xcframeworks + linked system frameworks/libs.
- `ios/Frameworks/.gitignore`, `ios/Frameworks/README.md`.
- `ios/scripts/install_insta360_sdk.sh` — copies the 3 xcframeworks from the SDK into `ios/Frameworks/`.
- `ios/Podfile` — `pod 'INSCameraSDK', :path => 'Frameworks'`.

---

## 4b. Pipeline parity (the milestones now run live on iOS)

The Android capture-side optimisation pipeline is ported to Swift under
`ios/Runner/Insta360/Pipeline/` and wired into the real frame path: every extracted flat-pano frame is
converted to RGBA8888, observed by the AI decision layer, and run through the pipeline **before** it
reaches the host texture / transmit path — replacing the earlier pass-through. `getPipelineMetrics`
now returns the real `PipelineMetrics.snapshot()` and the `setMask`/`setTemporal`/`setAi` toggles drive
the real stages.

Android → Swift map (same names for auditability), and the constants mirrored exactly:

| Android (`…/insta360/pipeline/`) | Swift (`…/Insta360/Pipeline/`) | Constants / rules mirrored |
|---|---|---|
| `FramePipeline.kt` | `FramePipeline.swift` | Ordered chain **Downscale → PanoramaDetect → ForwardMask → TemporalDedup**; drop-on-nil (records drop, stops); **fall-open on throw** (see note); per-stage + overall latency. |
| `FrameStage.kt` | `FrameStage.swift` | `process(frame, hints) -> frame?` (declared `throws` so the pipeline can fall open). |
| `PipelineFrame.kt` / `FrameMeta.kt` | `PipelineFrame.swift` | RGBA8888 tightly packed; `ptsUs` preserved unchanged through every stage; `meta.isPanoramic`, `forwardThetaDeg`. |
| `PipelineHints.kt` | `PipelineHints.swift` | `DeterministicHints` (all nil) + `MutableHints`. |
| `PipelineMetrics.kt` | `PipelineMetrics.swift` | EMA α **0.1**; keys `fps, framesIn, framesOut, framesDropped, totalMs, spatialReduction, stagesMs`; ordered `stagesMs`. |
| `PanoramaDetectStage.kt` | `PanoramaDetectStage.swift` | ERP aspect ~2:1, tolerance **0.15**; AI `isPanoramic` override. |
| `ForwardMaskStage.kt` | `ForwardMaskStage.swift` | Forward FOV **200°**, feather **6°**; centred keep band `(F/360)·W`; per-column factor table cached; suppressed → opaque black; **no wrap-around** (identical to Android). |
| `TemporalDedupStage.kt` | `TemporalDedupStage.swift` | `motionThreshold` **0.010**, `staticFps` **10**; PTS-based `minGap = 1e6/staticFps`; keep-if-moving-or-elapsed; 32×18 luma grid; BT.601 int luma `(77,150,29)>>8`; normalised MAD. |
| `DownscaleStage.kt` | `DownscaleStage.swift` | Tiers **1920×960 / 1600×800 / 1280×640 / 960×480**; `tierFor` thresholds **0.85/0.65/0.45**; dwell **2.5 s** (PTS-based) hysteresis; area-average box filter; reciprocal multiply-shift **RECIP_SHIFT 21**, **MAX_BOX 64**; never upscale; full tier = pass-through. |
| `HeuristicDecisionLayer.kt` | `HeuristicDecisionLayer.swift` | 32×18 grid; `TOP_FRACTION` **0.15**; EMA α motion **0.4** / detail **0.2** / theta **0.05**; `RECOMMEND_FLOOR` **0.5**; hysteresis enter **0.030** / exit **0.015**, hold **400 ms**, fixed ref lag **250 ms**; `perceptual = clamp(0.5 + 2·detail + 0.5·activity)`; `motion` emitted as decision 1/0; stats keys `aiEnabled…aiThetaDeg`. |

**Deliberate Swift deviations (behaviourally identical, documented):**
1. `FrameStage.process` is `throws` (Kotlin caught `Throwable`). Swift can't catch fatal traps (e.g.
   out-of-bounds), so genuine parity for *those* is impossible on any platform; the structural
   try/catch fall-open is preserved and any thrown error falls open exactly like Android.
2. `DownscaleStage` allocates the reduced-tier output buffer fresh per resample instead of reusing one
   persistent buffer — under Swift copy-on-write the reused buffer would alias `frame.pixels` and force
   the next in-place stage (mask) to copy, which is worse. **Output pixels are identical.**
3. Timing uses `DispatchTime.uptimeNanoseconds` (monotonic) in place of `System.nanoTime()`.
4. New iOS-only helper `PixelBufferFactory.swift`: converts processed RGBA → a BGRA `CVPixelBuffer`
   (pooled per output size) for the Flutter host `Texture`. Android uploads via GL; the pixels match.

**Verifiable on iOS now** via the existing Dart API:
- `getPipelineMetrics()` → live `spatialReduction`, `framesIn/Out/Dropped`, `stagesMs` per stage, plus
  `spatial*` (tier/switches/ratio), `temporal*` (keepRatio/motionKeeps/staticDrops), `ai*`
  (aiMoving/aiActivity/aiMotionSpans/aiRecommendedScale/aiOverheadMs).
- `setMaskEnabled(false)` → ForwardMask off (full 360° passes); `setTemporalEnabled(false)` → every
  frame kept (`keepRatio`→1); `setAiEnabled(false)` → hints cleared, Downscale pins full tier and the
  temporal pacer uses its own deterministic motion metric (the M2 arm).

---

## 5. Mac finish / build procedure

Prereqs: macOS + Xcode 15+, CocoaPods, FVM/Flutter as used by the repo, an **Apple Silicon** Mac
recommended (no x86_64 simulator slice in the SDK), a real Insta360 camera, a paid Apple Developer
team (External Accessory + provisioning profile).

1. **Stage the SDK frameworks** (once per checkout):
   ```sh
   ios/scripts/install_insta360_sdk.sh /path/to/iOS_v1.9.2/INSCameraSDKSample-bluetooth/Frameworks
   # or: export INSTA360_IOS_SDK=/path/.../Frameworks && ios/scripts/install_insta360_sdk.sh
   ```
   Confirms `ios/Frameworks/INSCameraSDK.xcframework`, `INSCameraServiceSDK.xcframework`, `INSCoreMedia.xcframework` exist.

2. **Pods**:
   ```sh
   fvm flutter pub get
   cd ios && pod install && cd ..
   ```

3. **Open the workspace** `ios/Runner.xcworkspace` (NOT the project). Verify the `Insta360` group's 5
   Swift files are in **Runner ▸ Build Phases ▸ Compile Sources** (the pbxproj was hand-edited; if any
   are missing, drag `ios/Runner/Insta360/` into the Runner target, "Create groups", add to Runner).

4. **Signing**: Runner target ▸ Signing & Capabilities ▸ select your Team; ensure a provisioning
   profile is issued. The app already has `aps-environment`, associated-domains, Sign in with Apple in
   `Runner.entitlements` — no new entitlement is required for USB accessory or Local Network (those are
   Info.plist-driven, not entitlement-driven).

5. **Minimum iOS**: deployment target is 15.0 (Podfile + `IPHONEOS_DEPLOYMENT_TARGET = 15.0`). Keep it.

6. **Build/run on a real device** (see AppDelegate's `#error`: physical **Debug** is blocked for this
   app because of Agora/Iris — use Profile/Release):
   ```sh
   fvm flutter run --profile   # or --release
   ```
   The SDK needs a physical camera; the simulator is disabled at runtime (`Insta360Support` returns
   unsupported on simulator).

7. **Test the flow** on device: join the camera's Wi-Fi in iOS Settings (or plug an MFi camera) →
   trigger `connect('wifi')`/`connect('usb')` → accept the **Local Network** prompt (Wi-Fi) → expect a
   `connection{connected:true}` event, the preview sphere, and `frameStats`. Toggle `setFrameStreaming`
   to exercise the RGBA frames path.

---

## 6. Gaps / risks — MUST verify on a Mac

**Build / project**
1. **`project.pbxproj` was hand-edited on Linux.** Structure was validated for ID consistency + line
   balance, but only Xcode can confirm the 5 files compile into Runner. If the project fails to open or
   the files aren't in Compile Sources, re-add them in Xcode (the source files themselves are correct).
2. **Swift ↔ ObjC framework import.** Code uses `import INSCameraSDK` / `import INSCameraServiceSDK` /
   `import INSCoreMedia` (all are modular — `module.modulemap` present). If Swift can't see a symbol,
   add the umbrella import to `Runner-Bridging-Header.h`. Not needed in theory; verify.
3. **`use_frameworks! :linkage => :static` + vendored dynamic frameworks.** Expected to work
   (dynamic vendored frameworks embed regardless), but confirm the app bundle actually contains the 3
   `.framework`s under `Frameworks/` and passes code-signing. If embedding misbehaves, the fallback is a
   manual "Embed & Sign" in the Runner target.
4. **Intel-Mac simulator can't link the SDK** (no x86_64 slice). Use an Apple Silicon Mac, or exclude
   the SDK from simulator builds. Device builds are unaffected.

**SDK API assumptions (marked `// TODO(mac): verify against SDK` in code)**
5. **USB-C X-series over the iOS SDK.** `usbManager` + the MFi `UISupportedExternalAccessoryProtocols`
   are Lightning/MFi-era. Whether a modern **USB-C** X3/X4/X5 connects to an iPhone via this 1.9.2
   `usbManager` path is **unconfirmed** — the reliable path on iOS is **Wi-Fi** (`socketManager`).
   Confirm which models/transports you must support and test each. The protocol list may need the exact
   product's protocol string.
6. **Connection error mapping.** The iOS SDK surfaces failures via
   `INSCameraConnectionErrorNotification` without Android's rich numeric codes. `onCameraConnectError`
   currently emits a generic Wi-Fi/USB remedy message (`code:0`). Inspect `notification.userInfo` on
   device for an `NSError`/code and map occupied / low-battery / wrong-network like Android's
   `connectErrorMessage`. There is **no retry/backoff** and **no `awaiting_usb_permission`** on iOS.
7. **Resolution / model detection.** `beginPreviewSequence` picks 2560×1280 for Nano else 3840×1920 via
   `currentCamera?.name` / `kInsta360CameraNameNano`, copied from the SDK sample. Verify the chosen
   resolution streams smoothly on your target models; 3840×1920 may be heavy — tune if needed.
8. **`setViewOrientation` is a no-op.** `INSRenderView` (1.9.2) exposes gesture recognizers but no
   public programmatic yaw/pitch setter, so look-around is by native pan/pinch. If you need the
   Flutter-driven slider like Android, find/confirm an `INSRenderView`/`INSRenderManager` orientation
   API and drive it.
9. **Warm-refresh / stitch seam.** Android restarts the stream ~1.2 s after first frame to remove
   near-seam overlap on first connect. Not ported — check whether the first iOS stitch shows the same
   overlap and port the dance if so.

**Feature parity**
10. **Pipeline is ported and wired (§4b) — CPU parity is authored, not yet compiler-verified.** The
    stages reproduce Android's constants/rules exactly and run on every frame. What remains is Mac-only:
    (a) confirm it compiles, (b) confirm the pixel-for-pixel output matches Android on a real feed,
    (c) check CPU headroom at 2K/30 — the mask + box-filter + two channel-swaps are plain-Swift
    unsafe-pointer loops (chosen for guaranteed parity over vImage, which would change the resampling
    math). If CPU-bound on device, move the **channel swaps** (not the box filter) to
    `vImagePermuteChannels_ARGB8888` and/or the mask fill to vImage — those preserve output; the box
    filter must stay CPU to keep `spatialReduction`/pixels identical.
11. **Local Network permission (iOS 14+).** Wi-Fi connect to `192.168.42.1` triggers the system Local
    Network prompt; `NSLocalNetworkUsageDescription` is set. If discovery needs Bonjour, add
    `NSBonjourServices`. Confirm the prompt appears and the socket connects on device.
12. **Camera-AP routing.** Unlike Android, iOS can't bind the process to the camera's Wi-Fi; iOS keeps
    internet on cellular while the camera AP has none. Usually fine, but verify the SDK reaches the
    camera when cellular data is on.
