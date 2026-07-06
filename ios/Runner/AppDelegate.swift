import Flutter
import UIKit
import PushKit
import UserNotifications
import flutter_callkit_incoming_maintained

#if DEBUG && !targetEnvironment(simulator)
#error("Physical iPhone Debug mode is blocked for Vyooo because Agora/Iris can crash with EXC_BAD_ACCESS. Use Profile/Release (flutter run --profile/--release).")
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // VoIP push — wakes the app for incoming calls when killed/backgrounded.
    let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
    voipRegistry.delegate = self
    voipRegistry.desiredPushTypes = [.voIP]

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    guard let registrar = self.registrar(forPlugin: "VyoooDeferredNativePlugins") else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    let channel = FlutterMethodChannel(
      name: "vyooo/deferred_native_plugins",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "registerAgora" {
        guard let self else {
          result(FlutterError(code: "no_registry", message: nil, details: nil))
          return
        }
        AgoraDeferredRegistration.register(with: self)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didUpdate credentials: PKPushCredentials,
    for type: PKPushType
  ) {
    let token = credentials.token.map { String(format: "%02x", $0) }.joined()
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(token)
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didInvalidatePushTokenFor type: PKPushType
  ) {
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    guard type == .voIP else {
      completion()
      return
    }

    let dict = payload.dictionaryPayload
    let firestoreCallId = (dict["callId"] as? String) ?? (dict["id"] as? String) ?? UUID().uuidString
    let callKitId = CallKitUuid.forCallId(firestoreCallId)
    let nameCaller = (dict["nameCaller"] as? String) ?? "Vyooo"
    let handle = (dict["handle"] as? String) ?? "Incoming call"
    let isVideo = (dict["isVideo"] as? Bool) ?? false

    let data = flutter_callkit_incoming_maintained.Data(
      id: callKitId,
      nameCaller: nameCaller,
      handle: handle,
      type: isVideo ? 1 : 0
    )
    var extra = dict as? [String: Any] ?? [:]
    extra["callId"] = firestoreCallId
    data.extra = extra as NSDictionary

    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(data, fromPushKit: true) {
      completion()
    }
  }

  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    let type = (userInfo["type"] as? String) ?? ""
    if type == "incoming_call" {
      completionHandler([])
      return
    }
    CallkitNotificationManager.shared.userNotificationCenter(
      center,
      willPresent: notification,
      withCompletionHandler: completionHandler
    )
  }
}
