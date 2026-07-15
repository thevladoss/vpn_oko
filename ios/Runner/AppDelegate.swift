import Flutter
import UIKit
import Libbox
import os.log

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    if #available(iOS 14.0, *) {
      Logger(subsystem: "com.example.vpnOko", category: "core")
        .log("libbox core \(LibboxVersion(), privacy: .public)")
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    VpnHostApiSetup.setUp(binaryMessenger: messenger, api: VpnHostApiImpl())
    VpnEventsStreamHandler.register(with: messenger, streamHandler: VpnEventListener.shared)
  }
}
