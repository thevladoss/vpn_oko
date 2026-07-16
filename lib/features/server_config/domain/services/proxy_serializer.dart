import 'dart:convert';

import 'package:vpn_osin/features/server_config/domain/entities/proxy_config.dart';

String proxyConfigToUrl(ProxyConfig config) => switch (config) {
  VlessConfig() => _vless(config),
  VmessConfig() => _vmess(config),
  TrojanConfig() => _trojan(config),
  ShadowsocksConfig() => _shadowsocks(config),
  Hysteria2Config() => _hysteria2(config),
};

String _vless(VlessConfig c) {
  final params = <String, String>{
    'type': c.transport,
    'security': c.security,
    if (c.sni != null) 'sni': c.sni!,
    if (c.flow != null) 'flow': c.flow!,
    if (c.publicKey != null) 'pbk': c.publicKey!,
    if (c.shortId != null) 'sid': c.shortId!,
    if (c.fingerprint != null) 'fp': c.fingerprint!,
    if (c.alpn.isNotEmpty) 'alpn': c.alpn.join(','),
    if (c.wsPath != null) 'path': c.wsPath!,
    if (c.wsHostHeader != null) 'host': c.wsHostHeader!,
    if (c.grpcServiceName != null) 'serviceName': c.grpcServiceName!,
  };
  return _authorityUrl('vless', c.uuid, c.host, c.port, params, c.name);
}

String _vmess(VmessConfig c) {
  final payload = <String, String>{
    'v': '2',
    'add': c.host,
    'port': '${c.port}',
    'id': c.uuid,
    'ps': c.name,
    'aid': '${c.alterId}',
    'scy': c.cipher,
    'net': c.network,
    'tls': c.tls ? 'tls' : '',
    'sni': c.sni ?? '',
    'alpn': c.alpn.join(','),
    'path': c.wsPath ?? '',
    'host': c.wsHostHeader ?? '',
  };
  final encoded = base64.encode(utf8.encode(jsonEncode(payload)));
  return 'vmess://$encoded';
}

String _trojan(TrojanConfig c) {
  final params = <String, String>{
    'type': c.network,
    if (c.sni != null) 'sni': c.sni!,
    if (c.alpn.isNotEmpty) 'alpn': c.alpn.join(','),
    if (c.wsPath != null) 'path': c.wsPath!,
    if (c.wsHostHeader != null) 'host': c.wsHostHeader!,
    if (c.allowInsecure) 'allowInsecure': '1',
  };
  return _authorityUrl('trojan', c.password, c.host, c.port, params, c.name);
}

String _hysteria2(Hysteria2Config c) {
  final params = <String, String>{
    if (c.sni != null) 'sni': c.sni!,
    if (c.obfs != null) 'obfs': c.obfs!,
    if (c.obfsPassword != null) 'obfs-password': c.obfsPassword!,
    if (c.allowInsecure) 'insecure': '1',
  };
  return _authorityUrl('hysteria2', c.password, c.host, c.port, params, c.name);
}

String _shadowsocks(ShadowsocksConfig c) {
  final userInfo = base64.encode(utf8.encode('${c.method}:${c.password}'));
  return 'ss://$userInfo@${c.host}:${c.port}#${Uri.encodeComponent(c.name)}';
}

String _authorityUrl(
  String scheme,
  String credential,
  String host,
  int port,
  Map<String, String> params,
  String name,
) {
  final query = params.isEmpty
      ? ''
      : '?${Uri(queryParameters: params).query}';
  return '$scheme://$credential@$host:$port$query'
      '#${Uri.encodeComponent(name)}';
}
