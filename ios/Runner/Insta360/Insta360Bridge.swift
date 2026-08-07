import Foundation
import Flutter
import ExternalAccessory
import INSCameraSDK
import INSCameraServiceSDK

/// Native bridge for the Insta360 capture feature on iOS. Behavioural mirror of the Android
/// `Insta360Bridge.kt`, exposing the identical Flutter channels so the same Dart
/// `Insta360LiveService` drives both platforms:
///  - MethodChannel `vyooo/insta360`         — control (connect/disconnect/streaming/status/...)
///  - EventChannel  `vyooo/insta360/events`  — connection/preview/frameStats/error events
///  - EventChannel  `vyooo/insta360/frames`  — raw RGBA frames (debug)
///
/// CONNECTION MODEL (differs from Android by necessity)
/// The iOS SDK connects via notifications, not an explicit `openCamera(type)`:
///   - USB  : an MFi camera on Lightning/USB is detected by `INSCameraManager.usbManager` (set up at
///            launch) through the External Accessory framework + the `UISupportedExternalAccessory
///            Protocols` Info.plist array. There is NO runtime USB-permission dialog like Android.
///   - Wi-Fi: `INSCameraManager.socketManager().setup()` connects to the camera AP (192.168.42.1).
/// In both cases the outcome arrives asynchronously as `INSCameraDidConnectNotification` /
/// `INSCameraConnectionErrorNotification`, which we translate to the same `connection` / `error`
/// events the Dart layer already understands.
final class Insta360Bridge: NSObject {

    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel
    private let frameChannel: FlutterEventChannel
    private let textureRegistry: FlutterTextureRegistry

    private var events: FlutterEventSink?
    private var frameSink: FlutterEventSink?

    private var processedTexture: Insta360ProcessedTexture?

    // Connect state (mirrors Android's connectRequested / isConnecting guard).
    private var connectRequested = false
    private var isConnecting = false
    private var connectType: Int = ConnectType.none

    private enum ConnectType { static let none = 0, usb = 1, wifi = 2 }

    // Camera SSID prefixes announced by the SDK's MFi protocols (for the USB pre-flight).
    private static let accessoryProtocols: Set<String> = [
        "com.insta360.camera", "com.insta360.onecontrol", "com.insta360.onexcontrol",
        "com.insta360.onex2control", "com.insta360.onercontrol", "com.insta360.nanoscontrol",
    ]

    init(messenger: FlutterBinaryMessenger, textureRegistry: FlutterTextureRegistry) {
        self.textureRegistry = textureRegistry
        methodChannel = FlutterMethodChannel(name: "vyooo/insta360", binaryMessenger: messenger)
        eventChannel = FlutterEventChannel(name: "vyooo/insta360/events", binaryMessenger: messenger)
        frameChannel = FlutterEventChannel(name: "vyooo/insta360/frames", binaryMessenger: messenger)
        super.init()

        methodChannel.setMethodCallHandler { [weak self] call, result in
            self?.onMethodCall(call, result: result)
        }
        eventChannel.setStreamHandler(EventStreamHandler(
            onListen: { [weak self] sink in self?.attachEvents(sink) },
            onCancel: { [weak self] in self?.detachEvents() }
        ))
        frameChannel.setStreamHandler(EventStreamHandler(
            onListen: { [weak self] sink in self?.attachFrames(sink) },
            onCancel: { [weak self] in self?.detachFrames() }
        ))

        registerCameraNotifications()
    }

    // MARK: - Event channels

    private func attachEvents(_ sink: @escaping FlutterEventSink) {
        events = sink
        Insta360FrameSink.shared.onStats = { [weak self] w, h, fps, count in
            self?.send("frameStats", ["width": w, "height": h, "fps": fps, "count": count])
        }
        Insta360PreviewView.onPreviewState = { [weak self] state in
            self?.send("previewState", ["state": state])
        }
    }

    private func detachEvents() {
        events = nil
        Insta360FrameSink.shared.onStats = nil
        Insta360PreviewView.onPreviewState = nil
    }

    /// Single-slot coalescing dispatch (mirrors Android): a live stream only needs the most recent
    /// frame, so we keep just the latest one pending and drop stale frames — memory stays bounded to
    /// ~1 in-flight + 1 pending regardless of main-thread load. Each RGBA frame is ~7 MB.
    private let pendingLock = NSLock()
    private var pendingFrame: [String: Any]?

    private func attachFrames(_ sink: @escaping FlutterEventSink) {
        frameSink = sink
        Insta360FrameSink.shared.onFrame = { [weak self] data, w, h, ptsUs in
            guard let self = self else { return }
            let frame: [String: Any] = [
                "bytes": FlutterStandardTypedData(bytes: data),
                "width": w, "height": h, "ptsUs": ptsUs,
            ]
            self.pendingLock.lock()
            let wasEmpty = self.pendingFrame == nil
            self.pendingFrame = frame
            self.pendingLock.unlock()
            if wasEmpty {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.pendingLock.lock()
                    let f = self.pendingFrame; self.pendingFrame = nil
                    self.pendingLock.unlock()
                    if let f = f { self.frameSink?(f) }
                }
            }
        }
    }

    private func detachFrames() {
        frameSink = nil
        Insta360FrameSink.shared.onFrame = nil
    }

    // MARK: - Method dispatch

    private func onMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isSupported":
            result(Insta360Support.isSupported)

        case "connect":
            handleConnect(call, result: result)

        case "disconnect":
            handleDisconnect(result: result)

        case "setFrameStreaming":
            let enabled = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? false
            Insta360FrameSink.shared.streamingEnabled = enabled
            result(nil)

        case "getStatus":
            result(status())

        case "getPipelineMetrics":
            result(Insta360FrameSink.shared.metrics())

        case "createProcessedTexture":
            let tex = processedTexture ?? Insta360ProcessedTexture(registry: textureRegistry)
            processedTexture = tex
            Insta360FrameSink.shared.onProcessedFrame = { [weak tex] buffer, _ in tex?.push(buffer) }
            result(Int(tex.textureId))

        case "disposeProcessedTexture":
            Insta360FrameSink.shared.onProcessedFrame = nil
            processedTexture?.dispose()
            processedTexture = nil
            result(nil)

        case "setMaskEnabled":
            Insta360FrameSink.shared.setMaskEnabled(boolArg(call, "enabled", true))
            result(nil)

        case "setTemporalEnabled":
            Insta360FrameSink.shared.setTemporalEnabled(boolArg(call, "enabled", true))
            result(nil)

        case "setAiEnabled":
            Insta360FrameSink.shared.setAiEnabled(boolArg(call, "enabled", true))
            result(nil)

        case "setViewOrientation":
            let a = call.arguments as? [String: Any]
            let yaw = Float((a?["yaw"] as? Double) ?? 0)
            let pitch = Float((a?["pitch"] as? Double) ?? 0)
            Insta360PreviewView.applyOrientation(yaw: yaw, pitch: pitch)
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func boolArg(_ call: FlutterMethodCall, _ key: String, _ def: Bool) -> Bool {
        (call.arguments as? [String: Any])?[key] as? Bool ?? def
    }

    // MARK: - Connect / disconnect

    private func handleConnect(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard Insta360Support.isSupported else {
            result(FlutterError(code: "unsupported",
                                message: "Insta360 unavailable on this device",
                                details: Insta360Support.initError))
            return
        }
        if INSCameraManager.sharedManager().cameraState == .connected {
            result(["status": "already_connected"])
            return
        }
        if isConnecting {
            result(["status": "already_connecting"])
            return
        }

        let type = (call.arguments as? [String: Any])?["type"] as? String ?? "usb"
        connectRequested = true

        if type == "wifi" {
            connectType = ConnectType.wifi
            isConnecting = true
            // Start (or restart) the Wi-Fi session. The phone must already be joined to the camera's
            // AP in iOS Settings; the SDK connects to 192.168.42.1. Outcome arrives via notification.
            INSCameraManager.socketManager().setup()
            result(["status": "connecting"])
        } else {
            connectType = ConnectType.usb
            // Pre-flight: is a supported MFi camera actually attached? (mirrors Android usb_no_device)
            if !isInsta360AccessoryAttached() {
                connectRequested = false
                result(FlutterError(
                    code: "usb_no_device",
                    message: "No camera found on USB. Connect an MFi Insta360 camera and, if iOS "
                        + "prompts, allow it to open Vyooo, then try again.",
                    details: nil))
                return
            }
            isConnecting = true
            // The usb (External Accessory) manager was set up at launch; ensure it's listening.
            INSCameraManager.usbManager().setup()
            // If the accessory is already attached the SDK may already be mid-handshake; the connect
            // notification will follow. (No USB-permission dialog on iOS.)
            result(["status": "connecting"])
        }
    }

    private func handleDisconnect(result: @escaping FlutterResult) {
        connectRequested = false
        isConnecting = false
        // Drop the Wi-Fi session if any; leave the USB (EA) manager listening for future plug-ins.
        INSCameraManager.socketManager().shutdown()
        connectType = ConnectType.none
        result(nil)
    }

    private func isInsta360AccessoryAttached() -> Bool {
        let connected = EAAccessoryManager.shared().connectedAccessories
        for accessory in connected {
            for proto in accessory.protocolStrings {
                if Self.accessoryProtocols.contains(proto) { return true }
            }
        }
        return false
    }

    // MARK: - Camera notifications → Dart events

    private func registerCameraNotifications() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(onCameraConnected),
                       name: Notification.Name(INSCameraDidConnectNotification), object: nil)
        nc.addObserver(self, selector: #selector(onCameraReconnected),
                       name: Notification.Name(INSCameraDidReconnectNotification), object: nil)
        nc.addObserver(self, selector: #selector(onCameraDisconnected),
                       name: Notification.Name(INSCameraDidDisconnectNotification), object: nil)
        nc.addObserver(self, selector: #selector(onCameraConnectError),
                       name: Notification.Name(INSCameraConnectionErrorNotification), object: nil)
    }

    @objc private func onCameraConnected() {
        connectRequested = false
        isConnecting = false
        if connectType == ConnectType.none { connectType = ConnectType.wifi } // best-effort
        send("connection", ["connected": true, "connectType": connectType])
    }

    @objc private func onCameraReconnected() {
        send("connection", ["connected": true, "connectType": connectType])
    }

    @objc private func onCameraDisconnected() {
        isConnecting = false
        Insta360FrameSink.shared.reset()
        let previous = connectType
        connectType = ConnectType.none
        send("connection", ["connected": false, "connectType": previous])
    }

    @objc private func onCameraConnectError(_ note: Notification) {
        connectRequested = false
        isConnecting = false
        // The iOS SDK reports failures via this notification; it does not expose the rich numeric
        // codes the Android SDK does. Surface a human cause + remedy (T3 parity) and keep any
        // userInfo in the log for diagnostics.
        NSLog("[Insta360] connection error userInfo=\(String(describing: note.userInfo))")
        let message = connectType == ConnectType.wifi
            ? "Couldn't connect over Wi-Fi. Join the camera's Wi-Fi network in iOS Settings "
                + "(it's named after the camera), then try again."
            : "Couldn't connect to the 360 camera. Check it's powered on, unplug and re-plug the "
                + "USB/Lightning cable, and allow it to open Vyooo if iOS asks, then try again."
        // TODO(mac): verify against SDK — inspect note.userInfo for an NSError/code and map specific
        // failures (occupied / low-battery / wrong-network) the way Android's connectErrorMessage does.
        send("error", ["scope": "connect", "code": 0, "message": message])
    }

    // MARK: - Status

    private func status() -> [String: Any] {
        let connected = INSCameraManager.sharedManager().cameraState == .connected
        return [
            "supported": Insta360Support.isSupported,
            "connected": connected,
            "connecting": isConnecting,
            "connectType": connected ? connectType : ConnectType.none,
            "streaming": Insta360FrameSink.shared.streamingEnabled,
        ]
    }

    private func send(_ event: String, _ extra: [String: Any]) {
        var payload = extra
        payload["event"] = event
        DispatchQueue.main.async { [weak self] in self?.events?(payload) }
    }

    func dispose() {
        NotificationCenter.default.removeObserver(self)
        methodChannel.setMethodCallHandler(nil)
        eventChannel.setStreamHandler(nil)
        frameChannel.setStreamHandler(nil)
        Insta360FrameSink.shared.onStats = nil
        Insta360FrameSink.shared.onFrame = nil
        Insta360FrameSink.shared.onProcessedFrame = nil
        Insta360PreviewView.onPreviewState = nil
        processedTexture?.dispose()
        processedTexture = nil
        events = nil
        frameSink = nil
    }
}

/// Small reusable `FlutterStreamHandler` that forwards to closures.
private final class EventStreamHandler: NSObject, FlutterStreamHandler {
    private let onListenCb: (@escaping FlutterEventSink) -> Void
    private let onCancelCb: () -> Void

    init(onListen: @escaping (@escaping FlutterEventSink) -> Void, onCancel: @escaping () -> Void) {
        onListenCb = onListen
        onCancelCb = onCancel
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        onListenCb(events)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        onCancelCb()
        return nil
    }
}
