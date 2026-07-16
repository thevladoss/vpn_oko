import Foundation
import Libbox
import Network
import NetworkExtension
import os.log

protocol TunnelHost: AnyObject {
  func applyTunnelSettings(_ settings: NEPacketTunnelNetworkSettings) throws -> Int32
  func requestTeardown()
}

enum ExtensionLog {
  static let handle = OSLog(subsystem: "com.example.vpnOsin.PacketTunnel", category: "core")

  static func write(_ message: String) {
    os_log("%{public}@", log: handle, type: .default, message)
  }
}

final class OsinPlatformInterface: NSObject {
  private weak var host: TunnelHost?
  private let monitorQueue = DispatchQueue(label: "osin.interface.monitor")
  private var pathMonitor: NWPathMonitor?

  init(host: TunnelHost) {
    self.host = host
    super.init()
  }
}

extension OsinPlatformInterface: LibboxPlatformInterfaceProtocol {
  func openTun(_ options: (any LibboxTunOptionsProtocol)?, ret0_: UnsafeMutablePointer<Int32>?) throws {
    guard let options else { throw failure("tun options missing") }
    guard let host else { throw failure("tunnel host released") }
    let settings = buildSettings(from: options)
    let descriptor = try host.applyTunnelSettings(settings)
    guard descriptor >= 0 else { throw failure("tunnel file descriptor unavailable") }
    ret0_?.pointee = descriptor
  }

  func usePlatformAutoDetectControl() -> Bool { false }

  func autoDetectControl(_ fd: Int32) throws {}

  func useProcFS() -> Bool { false }

  func findConnectionOwner(
    _ ipProtocol: Int32,
    sourceAddress: String?,
    sourcePort: Int32,
    destinationAddress: String?,
    destinationPort: Int32
  ) throws -> LibboxConnectionOwner {
    throw failure("findConnectionOwner not implemented")
  }

  func startDefaultInterfaceMonitor(_ listener: (any LibboxInterfaceUpdateListenerProtocol)?) throws {
    let monitor = NWPathMonitor()
    pathMonitor = monitor
    let ready = DispatchSemaphore(value: 0)
    let gate = FirstUpdateGate()
    monitor.pathUpdateHandler = { [weak self] path in
      self?.emit(path, to: listener)
      if gate.open() { ready.signal() }
    }
    monitor.start(queue: monitorQueue)
    ready.wait()
  }

  func closeDefaultInterfaceMonitor(_ listener: (any LibboxInterfaceUpdateListenerProtocol)?) throws {
    pathMonitor?.cancel()
    pathMonitor = nil
  }

  func getInterfaces() throws -> any LibboxNetworkInterfaceIteratorProtocol {
    let interfaces = pathMonitor?.currentPath.availableInterfaces ?? []
    let boxed = interfaces.map { interface -> LibboxNetworkInterface in
      let item = LibboxNetworkInterface()
      item.name = interface.name
      item.index = Self.interfaceIndex(interface.name)
      item.type = Self.interfaceType(interface.type)
      return item
    }
    return NetworkInterfaceArray(boxed)
  }

  func underNetworkExtension() -> Bool { true }

  func includeAllNetworks() -> Bool { false }

  func readWIFIState() -> LibboxWIFIState? { nil }

  func systemCertificates() -> (any LibboxStringIteratorProtocol)? { nil }

  func clearDNSCache() {}

  func send(_ notification: LibboxNotification?) throws {
    guard let notification else { return }
    let text = "\(notification.title) \(notification.body)".trimmingCharacters(in: .whitespaces)
    if !text.isEmpty { ExtensionLog.write(text) }
  }

  func localDNSTransport() -> (any LibboxLocalDNSTransportProtocol)? { nil }
}

extension OsinPlatformInterface: LibboxCommandServerHandlerProtocol {
  func serviceStop() throws {
    host?.requestTeardown()
  }

  func serviceReload() throws {}

  func getSystemProxyStatus() throws -> LibboxSystemProxyStatus {
    let status = LibboxSystemProxyStatus()
    status.available = false
    status.enabled = false
    return status
  }

  func setSystemProxyEnabled(_ isEnabled: Bool) throws {}

  func writeDebugMessage(_ message: String?) {
    guard let message, !message.isEmpty else { return }
    ExtensionLog.write(message)
  }
}

private extension OsinPlatformInterface {
  func buildSettings(from options: any LibboxTunOptionsProtocol) -> NEPacketTunnelNetworkSettings {
    let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
    guard options.getAutoRoute() else { return settings }

    settings.mtu = NSNumber(value: options.getMTU())

    if let dns = try? options.getDNSServerAddress(), !dns.value.isEmpty {
      settings.dnsSettings = NEDNSSettings(servers: [dns.value])
    }

    let inet4 = collect(options.getInet4Address())
    if !inet4.isEmpty {
      let ipv4 = NEIPv4Settings(
        addresses: inet4.map { $0.address() },
        subnetMasks: inet4.map { Self.ipv4Mask($0.prefix()) }
      )
      let routes = collect(options.getInet4RouteAddress())
      ipv4.includedRoutes = routes.isEmpty
        ? [NEIPv4Route.default()]
        : routes.map { NEIPv4Route(destinationAddress: $0.address(), subnetMask: Self.ipv4Mask($0.prefix())) }
      let excluded = collect(options.getInet4RouteExcludeAddress())
      if !excluded.isEmpty {
        ipv4.excludedRoutes = excluded.map {
          NEIPv4Route(destinationAddress: $0.address(), subnetMask: Self.ipv4Mask($0.prefix()))
        }
      }
      settings.ipv4Settings = ipv4
    }

    let inet6 = collect(options.getInet6Address())
    if !inet6.isEmpty {
      let ipv6 = NEIPv6Settings(
        addresses: inet6.map { $0.address() },
        networkPrefixLengths: inet6.map { NSNumber(value: $0.prefix()) }
      )
      let routes = collect(options.getInet6RouteAddress())
      ipv6.includedRoutes = routes.isEmpty
        ? [NEIPv6Route.default()]
        : routes.map {
          NEIPv6Route(destinationAddress: $0.address(), networkPrefixLength: NSNumber(value: $0.prefix()))
        }
      let excluded = collect(options.getInet6RouteExcludeAddress())
      if !excluded.isEmpty {
        ipv6.excludedRoutes = excluded.map {
          NEIPv6Route(destinationAddress: $0.address(), networkPrefixLength: NSNumber(value: $0.prefix()))
        }
      }
      settings.ipv6Settings = ipv6
    }

    return settings
  }

  func collect(_ iterator: (any LibboxRoutePrefixIteratorProtocol)?) -> [LibboxRoutePrefix] {
    guard let iterator else { return [] }
    var result: [LibboxRoutePrefix] = []
    while iterator.hasNext() {
      if let prefix = iterator.next() { result.append(prefix) }
    }
    return result
  }

  func emit(_ path: Network.NWPath, to listener: (any LibboxInterfaceUpdateListenerProtocol)?) {
    guard let listener else { return }
    if path.status == .unsatisfied {
      listener.updateDefaultInterface("", interfaceIndex: -1, isExpensive: false, isConstrained: false)
      return
    }
    let primary = path.availableInterfaces.first
    let name = primary?.name ?? ""
    let index = primary.map { Self.interfaceIndex($0.name) } ?? -1
    listener.updateDefaultInterface(
      name,
      interfaceIndex: index,
      isExpensive: path.isExpensive,
      isConstrained: path.isConstrained
    )
  }

  func failure(_ message: String) -> NSError {
    NSError(domain: "com.example.vpnOsin.PacketTunnel", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
  }

  static func interfaceIndex(_ name: String) -> Int32 {
    Int32(bitPattern: name.withCString { if_nametoindex($0) })
  }

  static func interfaceType(_ type: NWInterface.InterfaceType) -> Int32 {
    switch type {
    case .wifi: return LibboxInterfaceTypeWIFI
    case .cellular: return LibboxInterfaceTypeCellular
    case .wiredEthernet: return LibboxInterfaceTypeEthernet
    default: return LibboxInterfaceTypeOther
    }
  }

  static func ipv4Mask(_ prefix: Int32) -> String {
    let bits = max(0, min(32, Int(prefix)))
    let mask: UInt32 = bits == 0 ? 0 : UInt32.max << (32 - bits)
    return "\((mask >> 24) & 0xFF).\((mask >> 16) & 0xFF).\((mask >> 8) & 0xFF).\(mask & 0xFF)"
  }
}

private final class FirstUpdateGate {
  private var opened = false

  func open() -> Bool {
    if opened { return false }
    opened = true
    return true
  }
}

private final class NetworkInterfaceArray: NSObject, LibboxNetworkInterfaceIteratorProtocol {
  private let values: [LibboxNetworkInterface]
  private var index = 0

  init(_ values: [LibboxNetworkInterface]) {
    self.values = values
    super.init()
  }

  func hasNext() -> Bool {
    index < values.count
  }

  func next() -> LibboxNetworkInterface? {
    guard index < values.count else { return nil }
    defer { index += 1 }
    return values[index]
  }
}
