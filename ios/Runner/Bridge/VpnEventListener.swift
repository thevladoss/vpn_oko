import Foundation

final class VpnEventListener: VpnEventsStreamHandler {
  static let shared = VpnEventListener()

  private var eventSink: PigeonEventSink<VpnEventMessage>?
  private(set) var lastStatus = StatusChangedMessage(status: .disconnected)
  private var rxBytes: Int64 = 0
  private var txBytes: Int64 = 0

  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<VpnEventMessage>) {
    eventSink = sink
    emit(lastStatus)
  }

  override func onCancel(withArguments arguments: Any?) {
    eventSink = nil
  }

  func emit(_ event: VpnEventMessage) {
    if let status = event as? StatusChangedMessage {
      lastStatus = status
    } else if let traffic = event as? TrafficChangedMessage {
      rxBytes = traffic.rxBytes
      txBytes = traffic.txBytes
    }
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?.success(event)
    }
  }

  func snapshot() -> VpnStatusSnapshotMessage {
    return VpnStatusSnapshotMessage(
      status: lastStatus.status,
      connectedSinceEpochMs: lastStatus.connectedSinceEpochMs,
      rxBytes: rxBytes,
      txBytes: txBytes
    )
  }
}
