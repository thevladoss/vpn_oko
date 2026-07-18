import Foundation
import Libbox

final class TrafficLogClient: NSObject, LibboxCommandClientHandlerProtocol {
  private let listener: VpnEventListener
  private let queue = DispatchQueue(label: "osin.traffic.client")
  private var client: LibboxCommandClient?

  init(listener: VpnEventListener = .shared) {
    self.listener = listener
    super.init()
  }

  func start() {
    queue.async { [weak self] in
      guard let self, self.client == nil else { return }
      let options = LibboxCommandClientOptions()
      options.statusInterval = Int64(NSEC_PER_SEC)
      options.addCommand(LibboxCommandStatus)
      guard let client = LibboxNewCommandClient(self, options) else {
        return
      }
      do {
        try client.connect()
        self.client = client
      } catch {
      }
    }
  }

  func stop() {
    queue.async { [weak self] in
      guard let self, let client = self.client else { return }
      self.client = nil
      try? client.disconnect()
    }
  }

  func writeStatus(_ message: LibboxStatusMessage?) {
    guard let message else { return }
    listener.emit(TrafficChangedMessage(rxBytes: message.downlinkTotal, txBytes: message.uplinkTotal))
  }

  func writeLogs(_ messageList: (any LibboxLogIteratorProtocol)?) {}

  func connected() {}

  func disconnected(_ message: String?) {}

  func clearLogs() {}

  func initializeClashMode(_ modeList: (any LibboxStringIteratorProtocol)?, currentMode: String?) {}

  func setDefaultLogLevel(_ level: Int32) {}

  func updateClashMode(_ newMode: String?) {}

  func write(_ events: LibboxConnectionEvents?) {}

  func writeGroups(_ message: (any LibboxOutboundGroupIteratorProtocol)?) {}
}
