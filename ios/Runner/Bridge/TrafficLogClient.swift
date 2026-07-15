import Foundation
import Libbox

final class TrafficLogClient: NSObject, LibboxCommandClientHandlerProtocol {
  private let listener: VpnEventListener
  private let queue = DispatchQueue(label: "oko.traffic.client")
  private var client: LibboxCommandClient?
  private var statusTick = 0

  init(listener: VpnEventListener = .shared) {
    self.listener = listener
    super.init()
  }

  func start() {
    queue.async { [weak self] in
      guard let self, self.client == nil else { return }
      self.statusTick = 0
      let options = LibboxCommandClientOptions()
      options.statusInterval = Int64(NSEC_PER_SEC)
      options.addCommand(LibboxCommandStatus)
      options.addCommand(LibboxCommandLog)
      guard let client = LibboxNewCommandClient(self, options) else {
        self.emit("traffic client unavailable", level: "warning")
        return
      }
      do {
        try client.connect()
        self.client = client
      } catch {
        self.emit("traffic client connect failed: \(error.localizedDescription)", level: "warning")
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
    statusTick += 1
    if statusTick % 30 == 0 {
      emit("core memory \(message.memory) bytes", level: "info")
    }
  }

  func writeLogs(_ messageList: (any LibboxLogIteratorProtocol)?) {
    guard let messageList else { return }
    while messageList.hasNext() {
      guard let entry = messageList.next() else { break }
      emit(entry.message, level: "info")
    }
  }

  func connected() {
    emit("core stats channel connected", level: "info")
  }

  func disconnected(_ message: String?) {
    emit("core stats channel disconnected \(message ?? "")", level: "info")
  }

  func clearLogs() {}

  func initializeClashMode(_ modeList: (any LibboxStringIteratorProtocol)?, currentMode: String?) {}

  func setDefaultLogLevel(_ level: Int32) {}

  func updateClashMode(_ newMode: String?) {}

  func write(_ events: LibboxConnectionEvents?) {}

  func writeGroups(_ message: (any LibboxOutboundGroupIteratorProtocol)?) {}

  private func emit(_ text: String, level: String) {
    listener.emit(
      LogMessage(
        text: text,
        timestampMillis: Int64(Date().timeIntervalSince1970 * 1000),
        level: level
      )
    )
  }
}
