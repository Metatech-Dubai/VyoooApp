# 360 Live — Manual QA Checklist

**Branch:** `qa/360-live-integration`  
**Label:** QA only — 360 live integration — not for production  
**Base:** `metatech/main` @ `fbc1c8b`  
**Feature merged:** `metatech/feature/360-temporal-optimization` @ `2c68fea`  
**Integration merge:** `873875a` — `merge(qa): combine latest main design with 360 live feature`

> **Do not merge this QA branch.** Use [PR #6](https://github.com/Metatech-Dubai/VyoooApp/pull/6) for the production merge after hardware and regression testing.

## Automated checks (integration branch)

| Check | Status | Notes |
|-------|--------|-------|
| `fvm flutter pub get` | Pass | |
| `fvm dart format` | Pass | Merge-related Dart files only (repo-wide would touch 286 unrelated files) |
| `fvm flutter analyze` | Pass | 0 errors (28 pre-existing info/warnings on `main`) |
| `fvm flutter test` | Pass | 107/107 |
| `./scripts/verify_toolchain.sh` | Pass | Flutter 3.38.9 |
| `fvm flutter build apk --debug` | Pass | `build/qa/QA-only-360-live-integration-not-for-production-v1.2.4+50.apk` |
| `fvm flutter build ios --debug --no-codesign` | Pass | `build/ios/iphoneos/Runner.app` |

## Test environment

| Item | Value |
|------|-------|
| Platform (host 360) | Android 10+ (API 29+), Insta360 X4 via USB |
| Platform (viewer) | Android and iOS |
| Build | Debug APK from `qa/360-live-integration` |
| Firebase | Production project (no version-policy changes) |
| Media Push / HLS | **Disabled** — expect flat Agora viewer for 360 streams |

## Manual test matrix

Record **Pass / Fail / Blocked / N/A**, device model, OS version, tester name, and date for each row.

### Design merge (latest `main` UI)

| # | Scenario | Result | Tester | Date | Notes |
|---|----------|--------|--------|------|-------|
| D1 | Profile screen matches latest Figma (tabs, action buttons, stat typography) | | | | |
| D2 | Navigation shell / bottom bar unchanged for non-live flows | | | | |
| D3 | Creator live screen layout readable with latest theme tokens | | | | |
| D4 | Live stream viewer screen layout with latest design | | | | |
| D5 | Other major screens touched by recent `main` commits (reels, home, settings) | | | | |

### Normal phone-camera livestream (host)

| # | Scenario | Result | Tester | Date | Notes |
|---|----------|--------|--------|------|-------|
| H1 | Permissions (camera, mic) granted | | | | |
| H2 | Go live creates `streams/{id}` Firestore doc | | | | |
| H3 | Host preview shows phone camera | | | | |
| H4 | Viewer count / live badge updates | | | | |
| H5 | End stream cleans up Agora and Firestore status | | | | |
| H6 | Start → stop → restart same session flow | | | | |

### Normal livestream (viewer)

| # | Scenario | Result | Tester | Date | Notes |
|---|----------|--------|--------|------|-------|
| V1 | Join live stream via deep link / feed | | | | |
| V2 | Flat `AgoraVideoView` renders host video | | | | |
| V3 | Audio audible, no crash on leave | | | | |
| V4 | Non-360 stream never routes to `Live360View` | | | | |

### Insta360 X4 (Android host)

| # | Scenario | Result | Tester | Date | Notes |
|---|----------|--------|--------|------|-------|
| I1 | Insta360 option visible on Android only | | | | |
| I2 | USB connect — camera detected | | | | |
| I3 | Host preview (native GL) renders panorama | | | | |
| I4 | Gyro / look-around in preview | | | | |
| I5 | Go live writes `is360Video`, `projectionType`, `stereoMode` | | | | |
| I6 | External video frames pushed to Agora channel | | | | |
| I7 | iOS hides Insta360 capture UI (no `MissingPluginException`) | | | | |

### Flat panoramic Agora viewer (360 metadata, no HLS)

| # | Scenario | Result | Tester | Date | Notes |
|---|----------|--------|--------|------|-------|
| F1 | Viewer sees flat ERP video via Agora (not sphere) | | | | |
| F2 | Banner: "360° interactive view unavailable — showing live flat video" | | | | |
| F3 | No blank screen, infinite loader, or null URL crash | | | | |
| F4 | `Live360View` not entered without playable `hlsUrl` | | | | |

### Motion / pipeline (temporal optimisation)

| # | Scenario | Result | Tester | Date | Notes |
|---|----------|--------|--------|------|-------|
| M1 | Low-motion scene — stable preview, acceptable FPS | | | | |
| M2 | High-motion scene — no severe stutter or freeze | | | | |
| M3 | Panorama detect / temporal dedup — no visible glitches | | | | |

### Lifecycle and resilience

| # | Scenario | Result | Tester | Date | Notes |
|---|----------|--------|--------|------|-------|
| L1 | App background during live → resume | | | | |
| L2 | USB disconnect during preview → graceful error | | | | |
| L3 | USB reconnect → recover or clear message | | | | |
| L4 | Network interruption → reconnect or end gracefully | | | | |
| L5 | Camera and Agora cleanup on stream end | | | | |
| L6 | No resource leak after 3 start/stop cycles | | | | |

## Known limitations (expected on this build)

- **Interactive spherical viewer** requires `hlsUrl` from Agora Media Push → CDN; `MediaPushService.enabled == false`.
- **Insta360 host capture** is Android-only (minSdk 29).
- **Debug JIT + Agora on physical iPhone** may crash — use Profile/Release for device tests if needed.

## Sign-off

| Role | Name | Date | Approved |
|------|------|------|----------|
| QA | | | |
| Engineering | | | |
| Senior review | | | |

## After QA passes

1. Apply fixes to `feature/360-temporal-optimization` (not this QA branch).
2. Re-sync feature branch with latest `main`.
3. Run final automated checks on feature branch.
4. Obtain senior approval.
5. Convert PR #6 from Draft → Ready for Review.
6. Merge PR #6 into `main`.
7. Delete `qa/360-live-integration` after successful production merge.
