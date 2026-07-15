import Foundation

enum DemoLimit {
  static let sessionMs: Int64 = 300_000
  static let cooldownMs: Int64 = 120_000
}

protocol LongStore {
  func get(_ key: String) -> Int64?
  func set(_ key: String, _ value: Int64)
}

final class UserDefaultsLongStore: LongStore {
  private let defaults: UserDefaults

  init(defaults: UserDefaults) {
    self.defaults = defaults
  }

  func get(_ key: String) -> Int64? {
    guard let number = defaults.object(forKey: key) as? NSNumber else { return nil }
    return number.int64Value
  }

  func set(_ key: String, _ value: Int64) {
    defaults.set(NSNumber(value: value), forKey: key)
  }
}

final class DemoCooldownStore {
  private static let keyLastExpired = "last_expired_at"
  private static let keySessionEnds = "session_ends_at"

  private let store: LongStore

  init(store: LongStore) {
    self.store = store
  }

  func recordExpiry(_ now: Int64) {
    store.set(Self.keyLastExpired, now)
  }

  func cooldownUntil(_ now: Int64) -> Int64? {
    guard let lastExpiredAt = store.get(Self.keyLastExpired) else { return nil }
    let until = lastExpiredAt + DemoLimit.cooldownMs
    return until > now ? until : nil
  }

  func isInCooldown(_ now: Int64) -> Bool {
    cooldownUntil(now) != nil
  }

  func recordSessionEnd(_ atMs: Int64) {
    store.set(Self.keySessionEnds, atMs)
  }

  func sessionEndsAt() -> Int64? {
    store.get(Self.keySessionEnds)
  }

  static func shared() -> DemoCooldownStore {
    guard let defaults = UserDefaults(suiteName: AppGroup.id) else {
      fatalError("App Group \(AppGroup.id) UserDefaults недоступна: проверь entitlements Runner и PacketTunnel")
    }
    return DemoCooldownStore(store: UserDefaultsLongStore(defaults: defaults))
  }
}
