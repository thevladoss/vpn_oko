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
    ensureLibboxSetup()
    if #available(iOS 14.0, *) {
      Logger(subsystem: "com.example.vpnOsin", category: "core")
        .log("libbox core \(LibboxVersion(), privacy: .public)")
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    VpnHostApiSetup.setUp(binaryMessenger: messenger, api: VpnHostApiImpl())
    VpnEventsStreamHandler.register(with: messenger, streamHandler: VpnEventListener.shared)
  }

  private static var didSetupLibbox = false

  private func ensureLibboxSetup() {
    guard !AppDelegate.didSetupLibbox else { return }
    let options = LibboxSetupOptions()
    options.basePath = AppGroup.basePath
    options.workingPath = AppGroup.workingPath
    options.tempPath = AppGroup.cachePath
    options.logMaxLines = 3000
    var setupError: NSError?
    if LibboxSetup(options, &setupError) {
      AppDelegate.didSetupLibbox = true
    } else if #available(iOS 14.0, *) {
      Logger(subsystem: "com.example.vpnOsin", category: "core")
        .error("libbox setup failed: \(setupError?.localizedDescription ?? "unknown", privacy: .public)")
    }
  }
}
