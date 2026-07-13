import Foundation

final class VpnHostApiImpl: VpnHostApi {
  private let listener: VpnEventListener

  init(listener: VpnEventListener = .shared) {
    self.listener = listener
  }

  func startVpn(config: VpnConfigMessage, completion: @escaping (Result<Void, Error>) -> Void) {
    listener.emit(LogMessage(text: "starting vpn", timestampMillis: nowMillis(), level: "info"))
    listener.emit(StatusChangedMessage(status: .connecting))
    listener.emit(LogMessage(text: "tunnel up", timestampMillis: nowMillis(), level: "info"))
    listener.emit(StatusChangedMessage(status: .connected, connectedSinceEpochMs: nowMillis()))
    completion(.success(()))
  }

  func stopVpn(completion: @escaping (Result<Void, Error>) -> Void) {
    listener.emit(LogMessage(text: "stopping vpn", timestampMillis: nowMillis(), level: "info"))
    listener.emit(StatusChangedMessage(status: .disconnecting))
    listener.emit(StatusChangedMessage(status: .disconnected))
    completion(.success(()))
  }

  func getStatus() throws -> VpnStatusSnapshotMessage {
    return listener.snapshot()
  }

  private func nowMillis() -> Int64 {
    return Int64(Date().timeIntervalSince1970 * 1000)
  }
}
