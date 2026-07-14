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
    switch connection.status {
    case .connected:
      let since = connection.connectedDate.map { Int64($0.timeIntervalSince1970 * 1000) }
      listener.emit(StatusChangedMessage(status: .connected, connectedSinceEpochMs: since))
    case .connecting, .reasserting:
      listener.emit(StatusChangedMessage(status: .connecting))
    case .disconnecting:
      listener.emit(StatusChangedMessage(status: .disconnecting))
    case .disconnected:
      listener.emit(StatusChangedMessage(status: .disconnected))
    case .invalid:
      listener.emit(StatusChangedMessage(status: .error))
    @unknown default:
      listener.emit(StatusChangedMessage(status: .disconnected))
    }
  }

  deinit {
    if let token = token {
      NotificationCenter.default.removeObserver(token)
    }
  }
}
