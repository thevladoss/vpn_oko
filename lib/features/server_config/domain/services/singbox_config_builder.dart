import 'dart:convert';

import 'package:vpn_oko/features/server_config/domain/entities/proxy_config.dart';

Map<String, Object?> buildSingboxConfig(ProxyConfig config) {
  return {
    'log': {'level': 'warn'},
    'dns': _dns(),
    'inbounds': [_tunInbound()],
    'outbounds': [
      _proxyOutbound(config),
      {'type': 'direct', 'tag': 'direct'},
      {'type': 'dns', 'tag': 'dns-out'},
    ],
    'route': {
      'rules': [
        {'protocol': 'dns', 'outbound': 'dns-out'},
      ],
      'final': 'proxy',
      'auto_detect_interface': true,
    },
  };
}

String toSingboxJson(ProxyConfig config) =>
    jsonEncode(buildSingboxConfig(config));

Map<String, Object?> _dns() {
  return {
    'servers': [
      {'tag': 'proxy-dns', 'address': '1.1.1.1', 'detour': 'proxy'},
      {'tag': 'local', 'address': 'local', 'detour': 'direct'},
    ],
    'rules': [
      {'outbound': 'any', 'server': 'local'},
    ],
    'final': 'proxy-dns',
    'strategy': 'prefer_ipv4',
  };
}

Map<String, Object?> _tunInbound() {
  return {
    'type': 'tun',
    'tag': 'tun-in',
    'inet4_address': '172.19.0.1/28',
    'inet6_address': 'fdfe:dcba:9876::1/126',
    'mtu': 1500,
    'auto_route': true,
    'strict_route': false,
    'stack': 'gvisor',
    'sniff': true,
  };
}

Map<String, Object?> _proxyOutbound(ProxyConfig config) {
  switch (config) {
    case VlessConfig():
      return _vless(config);
    case VmessConfig():
      return _vmess(config);
    case TrojanConfig():
      return _trojan(config);
    case ShadowsocksConfig():
      return _shadowsocks(config);
    case Hysteria2Config():
      return _hysteria2(config);
  }
}

Map<String, Object?> _vless(VlessConfig config) {
  final tls = _tlsBlock(
    security: config.security,
    serverName: config.sni,
    fingerprint: config.fingerprint,
    publicKey: config.publicKey,
    shortId: config.shortId,
    alpn: config.alpn,
  );
  final transport = _transportBlock(
    network: config.transport,
    wsPath: config.wsPath,
    wsHostHeader: config.wsHostHeader,
    grpcServiceName: config.grpcServiceName,
  );
  return {
    'type': 'vless',
    'tag': 'proxy',
    'server': config.host,
    'server_port': config.port,
    'uuid': config.uuid,
    'packet_encoding': 'xudp',
    'flow': ?config.flow,
    'tls': ?tls,
    'transport': ?transport,
  };
}

Map<String, Object?> _vmess(VmessConfig config) {
  final tls = config.tls
      ? _tlsBlock(security: 'tls', serverName: config.sni, alpn: config.alpn)
      : null;
  final transport = _transportBlock(
    network: config.network,
    wsPath: config.wsPath,
    wsHostHeader: config.wsHostHeader,
  );
  return {
    'type': 'vmess',
    'tag': 'proxy',
    'server': config.host,
    'server_port': config.port,
    'uuid': config.uuid,
    'alter_id': config.alterId,
    'security': config.cipher,
    'tls': ?tls,
    'transport': ?transport,
  };
}

Map<String, Object?> _trojan(TrojanConfig config) {
  final tls = _tlsBlock(
    security: 'tls',
    serverName: config.sni,
    alpn: config.alpn,
    insecure: config.allowInsecure,
  );
  final transport = _transportBlock(
    network: config.network,
    wsPath: config.wsPath,
    wsHostHeader: config.wsHostHeader,
  );
  return {
    'type': 'trojan',
    'tag': 'proxy',
    'server': config.host,
    'server_port': config.port,
    'password': config.password,
    'tls': ?tls,
    'transport': ?transport,
  };
}

Map<String, Object?> _shadowsocks(ShadowsocksConfig config) {
  return {
    'type': 'shadowsocks',
    'tag': 'proxy',
    'server': config.host,
    'server_port': config.port,
    'method': config.method,
    'password': config.password,
  };
}

Map<String, Object?> _hysteria2(Hysteria2Config config) {
  final tls = _tlsBlock(
    security: 'tls',
    serverName: config.sni,
    insecure: config.allowInsecure,
  );
  return {
    'type': 'hysteria2',
    'tag': 'proxy',
    'server': config.host,
    'server_port': config.port,
    'password': config.password,
    if (config.obfs != null)
      'obfs': {
        'type': config.obfs,
        'password': ?config.obfsPassword,
      },
    'tls': ?tls,
  };
}

Map<String, Object?>? _tlsBlock({
  required String security,
  String? serverName,
  String? fingerprint,
  String? publicKey,
  String? shortId,
  List<String> alpn = const [],
  bool? insecure,
}) {
  if (security == 'none' || security.isEmpty) {
    return null;
  }
  final utls = fingerprint != null
      ? {'enabled': true, 'fingerprint': fingerprint}
      : null;
  final reality = security == 'reality' && publicKey != null
      ? {
          'enabled': true,
          'public_key': publicKey,
          'short_id': ?shortId,
        }
      : null;
  return {
    'enabled': true,
    'server_name': ?serverName,
    'insecure': ?insecure,
    if (alpn.isNotEmpty) 'alpn': alpn,
    'utls': ?utls,
    'reality': ?reality,
  };
}

Map<String, Object?>? _transportBlock({
  required String network,
  String? wsPath,
  String? wsHostHeader,
  String? grpcServiceName,
}) {
  switch (network) {
    case 'ws':
      return {
        'type': 'ws',
        'path': ?wsPath,
        if (wsHostHeader != null) 'headers': {'Host': wsHostHeader},
      };
    case 'grpc':
      return {
        'type': 'grpc',
        'service_name': ?grpcServiceName,
      };
    default:
      return null;
  }
}
