import Libbox
import NetworkExtension
import os.log

final class PacketTunnelProvider: NEPacketTunnelProvider, TunnelHost {
  private static var didSetup = false
  private static let setupLock = NSLock()

  private let workQueue = DispatchQueue(label: "oko.tunnel")
  private var commandServer: LibboxCommandServer?
  private var platform: OkoPlatformInterface?
  private var appliedSettings: NEPacketTunnelNetworkSettings?
  private var coreActive = false

  override func startTunnel(
    options: [String: NSObject]?,
    completionHandler: @escaping (Error?) -> Void
  ) {
    if #available(iOS 14.0, *) {
      Logger(subsystem: "com.example.vpnOko.PacketTunnel", category: "core")
        .log("libbox core \(LibboxVersion(), privacy: .public)")
    }
    let provided = options?["configContent"] as? String
    workQueue.async { [weak self] in
      self?.startCore(provided: provided, completionHandler: completionHandler)
    }
  }

  private func startCore(provided: String?, completionHandler: @escaping (Error?) -> Void) {
    let config: String
    if let provided, !provided.isEmpty {
      persistSnapshot(provided)
      config = provided
    } else if let snapshot = loadSnapshot() {
      config = snapshot
    } else {
      completionHandler(makeError("no singbox config supplied"))
      return
    }

    do {
      try ensureSetup()
    } catch {
      completionHandler(error)
      return
    }

    _ = LibboxRedirectStderr(AppGroup.cachePath + "/stderr.log", nil)
    LibboxSetMemoryLimit(true)

    let platformInterface = OkoPlatformInterface(host: self)
    var serverError: NSError?
    guard let server = LibboxNewCommandServer(platformInterface, platformInterface, &serverError) else {
      completionHandler(serverError ?? makeError("command server unavailable"))
      return
    }

    do {
      try server.start()
      try server.startOrReloadService(configForPlatform(config), options: LibboxOverrideOptions())
    } catch {
      server.close()
      completionHandler(error)
      return
    }

    commandServer = server
    platform = platformInterface
    coreActive = true
    completionHandler(nil)
  }

  private func ensureSetup() throws {
    Self.setupLock.lock()
    defer { Self.setupLock.unlock() }
    if Self.didSetup { return }
    let options = LibboxSetupOptions()
    options.basePath = AppGroup.basePath
    options.workingPath = AppGroup.workingPath
    options.tempPath = AppGroup.cachePath
    options.logMaxLines = 3000
    var setupError: NSError?
    guard LibboxSetup(options, &setupError) else {
      throw setupError ?? makeError("libbox setup failed")
    }
    Self.didSetup = true
  }

  private func configForPlatform(_ json: String) -> String {
    json
  }

  func applyTunnelSettings(_ settings: NEPacketTunnelNetworkSettings) throws -> Int32 {
    try runBlocking {
      try await self.setTunnelNetworkSettings(settings)
    }
    appliedSettings = settings
    if let descriptor = packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32,
       descriptor >= 0 {
      return descriptor
    }
    return LibboxGetTunnelFileDescriptor()
  }

  func requestTeardown() {
    teardown { [weak self] in
      self?.cancelTunnelWithError(nil)
    }
  }

  override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
    teardown { completionHandler() }
  }

  private func teardown(completion: @escaping () -> Void) {
    workQueue.async { [weak self] in
      guard let self else {
        completion()
        return
      }
      if self.coreActive {
        self.coreActive = false
        let server = self.commandServer
        self.commandServer = nil
        self.platform = nil
        try? server?.closeService()
        usleep(100_000)
        server?.close()
      }
      completion()
    }
  }

  private var snapshotURL: URL {
    AppGroup.containerURL.appendingPathComponent("startOptions.json")
  }

  private func persistSnapshot(_ config: String) {
    try? config.data(using: .utf8)?.write(to: snapshotURL, options: .atomic)
  }

  private func loadSnapshot() -> String? {
    guard let data = try? Data(contentsOf: snapshotURL) else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private func makeError(_ message: String) -> NSError {
    NSError(domain: "com.example.vpnOko.PacketTunnel", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
  }
}
