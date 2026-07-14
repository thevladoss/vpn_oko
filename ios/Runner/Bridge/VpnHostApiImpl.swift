import Foundation
import NetworkExtension

final class VpnHostApiImpl: VpnHostApi {
  private let listener: VpnEventListener
  private let observer = VpnStatusObserver()
  private var manager: NETunnelProviderManager?

  init(listener: VpnEventListener = .shared) {
    self.listener = listener
  }

  func startVpn(config: VpnConfigMessage, completion: @escaping (Result<Void, Error>) -> Void) {
    listener.emit(LogMessage(text: "starting vpn", timestampMillis: nowMillis(), level: "info"))
    listener.emit(StatusChangedMessage(status: .connecting))

    #if targetEnvironment(simulator)
    listener.emit(
      LogMessage(
        text: "Network Extension недоступен в симуляторе",
        timestampMillis: nowMillis(),
        level: "warning"
      )
    )
    NETunnelProviderManager.loadAllFromPreferences { _, _ in
      self.fail(code: "ne_unavailable", message: "Network Extension недоступен в симуляторе")
    }
    completion(.success(()))
    #else
    NETunnelProviderManager.loadAllFromPreferences { managers, error in
      if let error = error {
        self.fail(code: "ne_error", message: error.localizedDescription)
        completion(.success(()))
        return
      }

      let manager = managers?.first ?? NETunnelProviderManager()
      self.manager = manager
      let proto = NETunnelProviderProtocol()
      proto.providerBundleIdentifier = "com.example.vpnOko.PacketTunnel"
      proto.serverAddress = config.host
      proto.providerConfiguration = ["host": config.host, "port": config.port]
      manager.protocolConfiguration = proto
      manager.localizedDescription = "Oko VPN"
      manager.isEnabled = true

      manager.saveToPreferences { error in
        if let error = error {
          self.fail(code: "ne_error", message: error.localizedDescription)
          completion(.success(()))
          return
        }

        manager.loadFromPreferences { error in
          if let error = error {
            self.fail(code: "ne_error", message: error.localizedDescription)
            completion(.success(()))
            return
          }

          do {
            self.observer.attach(manager.connection)
            try manager.connection.startVPNTunnel()
            completion(.success(()))
          } catch {
            self.fail(code: "ne_error", message: error.localizedDescription)
            completion(.success(()))
          }
        }
      }
    }
    #endif
  }

  func stopVpn(completion: @escaping (Result<Void, Error>) -> Void) {
    listener.emit(LogMessage(text: "stopping vpn", timestampMillis: nowMillis(), level: "info"))
    listener.emit(StatusChangedMessage(status: .disconnecting))

    #if targetEnvironment(simulator)
    listener.emit(StatusChangedMessage(status: .disconnected))
    #else
    if let manager = self.manager {
      manager.connection.stopVPNTunnel()
    } else {
      NETunnelProviderManager.loadAllFromPreferences { managers, _ in
        guard let manager = managers?.first else { return }
        self.manager = manager
        self.observer.attach(manager.connection)
        manager.connection.stopVPNTunnel()
      }
    }
    #endif

    completion(.success(()))
  }

  func getStatus() throws -> VpnStatusSnapshotMessage {
    return listener.snapshot()
  }

  private func fail(code: String, message: String) {
    listener.emit(ErrorMessage(code: code, message: message))
    listener.emit(StatusChangedMessage(status: .error))
  }

  private func nowMillis() -> Int64 {
    return Int64(Date().timeIntervalSince1970 * 1000)
  }
}
