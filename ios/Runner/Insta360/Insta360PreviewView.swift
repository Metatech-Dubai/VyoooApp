import Foundation
import Flutter
import UIKit
import INSCameraSDK
import INSCameraServiceSDK
import INSCoreMedia

/// PlatformView hosting the SDK's live preview. iOS mirror of the Android `Insta360PreviewView`.
///
/// While mounted it:
///  1. builds an interactive panoramic `INSRenderView` (spherical render, native pan/pinch),
///  2. starts an `INSCameraMediaSession` with two pluggables:
///       - `INSCameraPreviewPlayer`  → renders the live sphere into the render view,
///       - `INSCameraFlatPanoOutput` → stitches the feed to a flat ERP `CVPixelBuffer` we forward to
///                                     `Insta360FrameSink` (host texture + transmit path).
///
/// Requires the camera to already be connected (Dart mounts this view only once connected, exactly
/// like Android). Unmounting stops the session and unplugs the outputs.
///
/// Flutter view type: `vyooo/insta360_preview` (identical to Android).
final class Insta360PreviewView: NSObject, FlutterPlatformView, INSCameraAVOutputDelegate {

    private let container = UIView()
    private var renderView: INSRenderView?
    private let mediaSession = INSCameraMediaSession()
    private var previewPlayer: INSCameraPreviewPlayer?
    private var flatPanoOutput: INSCameraFlatPanoOutput?

    private var disposed = false
    private var firstFrameSeen = false

    private let extractWidth: Int
    private let extractHeight: Int
    private let frameQueue = DispatchQueue(label: "com.vyooo.insta360.flatpano")

    init(frame: CGRect, viewId: Int64, args: Any?) {
        let params = args as? [String: Any]
        extractWidth = (params?["width"] as? Int) ?? 1920
        extractHeight = (params?["height"] as? Int) ?? 960
        super.init()

        Insta360PreviewView.active = self
        container.frame = frame
        container.backgroundColor = .black
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        buildRenderView(frame: frame.isEmpty ? UIScreen.main.bounds : frame)
        beginPreviewSequence()
    }

    func view() -> UIView { container }

    // MARK: - Setup

    private func buildRenderView(frame: CGRect) {
        let rv = INSRenderView(frame: container.bounds.isEmpty ? frame : container.bounds,
                               renderType: .sphericalPanoRender)
        rv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // On iOS, touches DO reach embedded platform views, so we can use the SDK's native gesture
        // system directly (Android had to forward drags from Flutter). Host looks around by dragging.
        rv.enablePanGesture = true
        rv.enablePinchGesture = true
        rv.enableGyroStabilizer = true
        container.addSubview(rv)
        renderView = rv
    }

    private func beginPreviewSequence() {
        guard let renderView = renderView else { return }
        mediaSession.gyroPlayMode = .normal

        // Resolution per connected model (mirrors the SDK sample AVOutputViewController).
        let name = INSCameraManager.sharedManager().currentCamera?.name
        if name == kInsta360CameraNameNano {
            renderView.enableGyroStabilizer = false
            mediaSession.expectedVideoResolution = INSVideoResolution2560x1280x30
        } else {
            mediaSession.expectedVideoResolution = INSVideoResolution3840x1920x30
        }
        mediaSession.expectedAudioSampleRate = .rate48000Hz

        // Interactive sphere render.
        let player = INSCameraPreviewPlayer(renderView: renderView)
        mediaSession.plug(player)
        previewPlayer = player

        // Flat ERP output for the transmit / host-texture path.
        let output = INSCameraFlatPanoOutput(outputWidth: extractWidth, outputHeight: extractHeight)
        output.outputPixelFormat = kCVPixelFormatType_32BGRA
        output.enableGyroStabilization = true
        output.setDelegate(self, onDispatchQueue: frameQueue)
        mediaSession.plug(output)
        flatPanoOutput = output

        // First mount: signal "warming" so the UI holds its overlay until the first frame renders.
        Insta360PreviewView.onPreviewState?("warming")

        mediaSession.startRunning { [weak self] error in
            if let error = error {
                NSLog("[Insta360] mediaSession start failed: \(error.localizedDescription)")
                // Don't strand the overlay — let Dart's own fallback timeout drop it.
                self?.emitPreviewStateReadyIfNeeded()
            }
        }
    }

    // MARK: - INSCameraAVOutputDelegate

    func avOutput(_ avOutput: INSCameraAVOutput, didOutputVideoFrame videoFrame: INSCameraVideoFrame) {
        guard !disposed else { return }
        Insta360FrameSink.shared.submit(pixelBuffer: videoFrame.pixelBuffer,
                                        timestamp: videoFrame.timestamp)
        if !firstFrameSeen {
            firstFrameSeen = true
            // TODO(mac): verify against SDK — Android does a one-shot "warm refresh" (restart the
            // stream ~1.2s after first frame) to rebuild the stitch from warm calibration and remove
            // near-seam overlap. If the first iOS stitch shows the same overlap on-device, port that
            // dance here. For now we report ready on the first rendered frame.
            emitPreviewStateReadyIfNeeded()
        }
    }

    private func emitPreviewStateReadyIfNeeded() {
        DispatchQueue.main.async { Insta360PreviewView.onPreviewState?("ready") }
    }

    // MARK: - Orientation (best-effort)

    /// Point the interactive view at an absolute (yaw, pitch) in degrees. Called from the bridge's
    /// `setViewOrientation`. Native pan/pinch already lets the host look around directly; a
    /// programmatic setter is not exposed by `INSRenderView` in 1.9.2, so this is a no-op for now.
    // TODO(mac): verify against SDK — if a programmatic camera-orientation API exists on
    // INSRenderView / INSRenderManager, drive it here to match Android's setYaw/setPitch.
    func applyOrientation(yaw: Float, pitch: Float) { /* native gestures handle look-around */ }

    // MARK: - Teardown

    func dispose() {
        if disposed { return }
        disposed = true
        if Insta360PreviewView.active === self { Insta360PreviewView.active = nil }
        mediaSession.unplugAll()
        mediaSession.stopRunning(completion: nil)
        previewPlayer = nil
        flatPanoOutput = nil
        renderView?.destroyRender()
        renderView?.removeFromSuperview()
        renderView = nil
        Insta360FrameSink.shared.streamingEnabled = false
    }

    deinit { dispose() }

    // MARK: - Static wiring (single mounted preview at a time)

    /// The currently-mounted preview. Only one exists at a time (matches Android).
    private(set) static weak var active: Insta360PreviewView?

    /// Host preview lifecycle signal for Flutter ("warming" → "ready"). Wired by `Insta360Bridge`.
    static var onPreviewState: ((String) -> Void)?

    /// Point the live interactive view at an absolute (yaw, pitch) in degrees. No-op if none mounted.
    static func applyOrientation(yaw: Float, pitch: Float) {
        active?.applyOrientation(yaw: yaw, pitch: pitch)
    }
}

/// Builds `Insta360PreviewView` for the Flutter view type `vyooo/insta360_preview`.
final class Insta360PreviewViewFactory: NSObject, FlutterPlatformViewFactory {
    override init() { super.init() }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        Insta360PreviewView(frame: frame, viewId: viewId, args: args)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}
