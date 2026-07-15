import Foundation

func runBlocking<T>(_ body: @escaping () async throws -> T) throws -> T {
  let semaphore = DispatchSemaphore(value: 0)
  let box = ResultBox<T>()
  Task.detached {
    do {
      box.value = .success(try await body())
    } catch {
      box.value = .failure(error)
    }
    semaphore.signal()
  }
  semaphore.wait()
  return try box.value!.get()
}

func runBlocking<T>(_ body: @escaping () async -> T) -> T {
  let semaphore = DispatchSemaphore(value: 0)
  let box = ResultBox<T>()
  Task.detached {
    box.value = .success(await body())
    semaphore.signal()
  }
  semaphore.wait()
  return try! box.value!.get()
}

private final class ResultBox<T> {
  var value: Result<T, Error>?
}
