import Foundation

enum AppGroup {
  static let id = "group.com.example.vpnOko"

  static var containerURL: URL {
    guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) else {
      fatalError("App Group \(id) недоступна: проверь entitlements Runner и PacketTunnel")
    }
    return url
  }

  static var basePath: String {
    directory(containerURL).relativePath
  }

  static var cachePath: String {
    directory(containerURL.appendingPathComponent("Library/Caches", isDirectory: true)).relativePath
  }

  static var workingPath: String {
    directory(containerURL.appendingPathComponent("Library/Caches/Working", isDirectory: true)).relativePath
  }

  private static func directory(_ url: URL) -> URL {
    let manager = FileManager.default
    if !manager.fileExists(atPath: url.path) {
      try? manager.createDirectory(at: url, withIntermediateDirectories: true)
    }
    return url
  }
}
