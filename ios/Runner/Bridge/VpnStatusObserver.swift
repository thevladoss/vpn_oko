import NetworkExtension

final class VpnStatusObserver {
  private let listener: VpnEventListener
  private var token: NSObjectProtocol?

  init(listener: VpnEventListener = .shared) {
    self.listener = listener
  }

  func attach(_ connection: NEVPNConnection, emitInitial: Bool = false) {
    if let token = token {
      NotificationCenter.default.removeObserver(token)
    }
    token = NotificationCenter.default.addObserver(
      forName: .NEVPNStatusDidChange,
      object: connection,
      queue: nil
    ) { [weak self] _ in
      self?.report(connection)
    }
    if emitInitial {
      report(connection)
    }
  }

  private func report(_ connection: NEVPNConnection) {
    log("ne status=\(statusName(connection.status))")
    switch connection.status {
    case .connected:
      let since = connection.connectedDate.map { Int64($0.timeIntervalSince1970 * 1000) }
      listener.emit(StatusChangedMessage(status: .connected, connectedSinceEpochMs: since))
    case .connecting, .reasserting:
      listener.emit(StatusChangedMessage(status: .connecting))
    case .disconnecting:
      listener.emit(StatusChangedMessage(status: .disconnecting))
    case .disconnected:
      fetchDisconnectError(connection)
      listener.emit(StatusChangedMessage(status: .disconnected))
    case .invalid:
      listener.emit(StatusChangedMessage(status: .error))
    @unknown default:
      listener.emit(StatusChangedMessage(status: .disconnected))
    }
  }

  private func fetchDisconnectError(_ connection: NEVPNConnection) {
    if #available(iOS 16.0, *) {
      connection.fetchLastDisconnectError { [weak self] error in
        guard let error = error else { return }
        self?.log("ne disconnect error: \(error.localizedDescription)")
      }
    }
  }

  private func log(_ text: String) {
    listener.emit(
      LogMessage(
        text: text,
        timestampMillis: Int64(Date().timeIntervalSince1970 * 1000),
        level: "debug"
      )
    )
  }

  private func statusName(_ status: NEVPNStatus) -> String {
    switch status {
    case .invalid: return "invalid"
    case .disconnected: return "disconnected"
    case .connecting: return "connecting"
    case .connected: return "connected"
    case .reasserting: return "reasserting"
    case .disconnecting: return "disconnecting"
    @unknown default: return "unknown"
    }
  }

  deinit {
    if let token = token {
      NotificationCenter.default.removeObserver(token)
    }
  }
}
