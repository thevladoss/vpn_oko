import NetworkExtension

final class VpnStatusObserver {
  private let listener: VpnEventListener
  private let store: DemoCooldownStore
  private var token: NSObjectProtocol?
  private var lastReported: NEVPNStatus?
  var onStatus: ((NEVPNStatus) -> Void)?

  init(listener: VpnEventListener = .shared, store: DemoCooldownStore = .shared()) {
    self.listener = listener
    self.store = store
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
    onStatus?(connection.status)
    switch connection.status {
    case .connected:
      let since = connection.connectedDate.map { Int64($0.timeIntervalSince1970 * 1000) }
      listener.emit(StatusChangedMessage(status: .connected, connectedSinceEpochMs: since))
    case .connecting, .reasserting:
      listener.emit(StatusChangedMessage(status: .connecting))
    case .disconnecting:
      listener.emit(StatusChangedMessage(status: .disconnecting))
    case .disconnected:
      reportDisconnected()
    case .invalid:
      listener.emit(StatusChangedMessage(status: .error))
    @unknown default:
      listener.emit(StatusChangedMessage(status: .disconnected))
    }
    lastReported = connection.status
  }

  private func reportDisconnected() {
    let now = Int64(Date().timeIntervalSince1970 * 1000)
    if wasActive(lastReported), let until = store.cooldownUntil(now) {
      listener.emit(LogMessage(text: "demo limit reached", timestampMillis: now, level: "info"))
      listener.emit(DemoExpiredMessage(cooldownUntilEpochMs: until))
    }
    listener.emit(StatusChangedMessage(status: .disconnected))
  }

  private func wasActive(_ status: NEVPNStatus?) -> Bool {
    switch status {
    case .some(.connected), .some(.connecting), .some(.reasserting), .some(.disconnecting):
      return true
    default:
      return false
    }
  }

  deinit {
    if let token = token {
      NotificationCenter.default.removeObserver(token)
    }
  }
}
