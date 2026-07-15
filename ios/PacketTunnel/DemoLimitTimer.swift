import Foundation

final class DemoLimitTimer {
  private let queue = DispatchQueue(label: "oko.demo.timer")
  private var source: DispatchSourceTimer?

  func schedule(afterMs: Int64, handler: @escaping () -> Void) {
    cancel()
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(wallDeadline: .now() + .milliseconds(Int(afterMs)))
    timer.setEventHandler(handler: handler)
    source = timer
    timer.resume()
  }

  func cancel() {
    source?.cancel()
    source = nil
  }
}
