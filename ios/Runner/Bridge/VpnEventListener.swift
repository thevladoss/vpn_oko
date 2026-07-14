import Foundation

final class VpnEventListener: VpnEventsStreamHandler {
  static let shared = VpnEventListener()

  private let stateLock = NSLock()
  private var eventSink: PigeonEventSink<VpnEventMessage>?
  private var storedStatus = StatusChangedMessage(status: .disconnected)
  private var rxBytes: Int64 = 0
  private var txBytes: Int64 = 0

  var lastStatus: StatusChangedMessage {
    stateLock.lock()
    defer { stateLock.unlock() }
    return storedStatus
  }

  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<VpnEventMessage>) {
    eventSink = sink
    emit(lastStatus)
  }

  override func onCancel(withArguments arguments: Any?) {
    eventSink = nil
  }

  func emit(_ event: VpnEventMessage) {
    stateLock.lock()
    if let status = event as? StatusChangedMessage {
      storedStatus = status
    } else if let traffic = event as? TrafficChangedMessage {
      rxBytes = traffic.rxBytes
      txBytes = traffic.txBytes
    }
    stateLock.unlock()
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?.success(event)
    }
  }

  func snapshot() -> VpnStatusSnapshotMessage {
    stateLock.lock()
    defer { stateLock.unlock() }
    return VpnStatusSnapshotMessage(
      status: storedStatus.status,
      connectedSinceEpochMs: storedStatus.connectedSinceEpochMs,
      rxBytes: rxBytes,
      txBytes: txBytes
    )
  }
}
