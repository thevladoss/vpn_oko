import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
  override func startTunnel(options: [String: NSObject]?,
                            completionHandler: @escaping (Error?) -> Void) {
    NSLog("OKOVPN PacketTunnel startTunnel entered")
    let proto = protocolConfiguration as? NETunnelProviderProtocol
    let server = proto?.serverAddress ?? "10.0.0.1"
    NSLog("OKOVPN PacketTunnel server=%@", server)

    let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.0.0.1")
    let ipv4 = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.255"])
    ipv4.includedRoutes = [NEIPv4Route(destinationAddress: "10.111.222.0",
                                       subnetMask: "255.255.255.0")]
    settings.ipv4Settings = ipv4
    settings.dnsSettings = NEDNSSettings(servers: ["1.1.1.1"])
    settings.mtu = 1500

    setTunnelNetworkSettings(settings) { error in
      NSLog("OKOVPN PacketTunnel setTunnelNetworkSettings error=%@",
            error.map { "\($0)" } ?? "nil")
      completionHandler(error)
    }
  }

  override func stopTunnel(with reason: NEProviderStopReason,
                           completionHandler: @escaping () -> Void) {
    completionHandler()
  }
}
