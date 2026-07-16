import 'dart:convert';

import 'package:vpn_osin/features/server_config/domain/entities/proxy_config.dart';
import 'package:vpn_osin/features/server_config/domain/entities/proxy_parse_result.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription_import.dart';
import 'package:vpn_osin/features/server_config/domain/services/proxy_parser.dart';

SubscriptionFormat detectSubscriptionFormat(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) {
    return SubscriptionFormat.unknown;
  }
  final decoded = _tryDecodeBase64(trimmed);
  if (decoded != null && decoded.contains('://')) {
    return SubscriptionFormat.base64List;
  }
  if (trimmed.startsWith('{')) {
    return SubscriptionFormat.singboxJson;
  }
  if (_hasClashProxies(trimmed)) {
    return SubscriptionFormat.clashYaml;
  }
  if (trimmed.contains('://')) {
    return SubscriptionFormat.uriList;
  }
  return SubscriptionFormat.unknown;
}

SubscriptionImport parseSubscription(String body) {
  final format = detectSubscriptionFormat(body);
  switch (format) {
    case SubscriptionFormat.base64List:
      return _parseUriLines(_tryDecodeBase64(body.trim()) ?? '', format);
    case SubscriptionFormat.uriList:
      return _parseUriLines(body, format);
    case SubscriptionFormat.singboxJson:
      return _parseSingbox(body);
    case SubscriptionFormat.clashYaml:
    case SubscriptionFormat.unknown:
      return _empty(format);
  }
}

String proxyDedupKey(ProxyConfig config) {
  final credential = switch (config) {
    VlessConfig(:final uuid) => uuid,
    VmessConfig(:final uuid) => uuid,
    TrojanConfig(:final password) => password,
    ShadowsocksConfig(:final password) => password,
    Hysteria2Config(:final password) => password,
  };
  return '${config.host}:${config.port}:$credential';
}

SubscriptionImport _parseUriLines(String text, SubscriptionFormat format) {
  final servers = <ImportedProxy>[];
  final seen = <String>{};
  var skipped = 0;
  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      continue;
    }
    switch (parseProxyUrl(line)) {
      case ProxyParsed(:final config):
        if (seen.add(proxyDedupKey(config))) {
          servers.add(ImportedProxy(config: config, rawUrl: line));
        } else {
          skipped++;
        }
      case ProxyParseFailure():
        skipped++;
    }
  }
  return SubscriptionImport(servers: servers, skipped: skipped, format: format);
}

SubscriptionImport _empty(SubscriptionFormat format) =>
    SubscriptionImport(servers: const [], skipped: 0, format: format);

bool _hasClashProxies(String body) =>
    body.split('\n').any((line) => line.trimLeft().startsWith('proxies:'));

String? _tryDecodeBase64(String input) {
  final compact = input.replaceAll(RegExp(r'\s'), '');
  if (compact.isEmpty) {
    return null;
  }
  try {
    return utf8.decode(base64.decode(base64.normalize(compact)));
  } on FormatException {
    return null;
  }
}

const _singboxServiceTypes = {
  'direct',
  'block',
  'dns',
  'selector',
  'urltest',
};

SubscriptionImport _parseSingbox(String body) {
  Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return _empty(SubscriptionFormat.singboxJson);
  }
  if (decoded is! Map<String, dynamic>) {
    return _empty(SubscriptionFormat.singboxJson);
  }
  final raw = decoded['outbounds'];
  if (raw is! List) {
    return _empty(SubscriptionFormat.singboxJson);
  }

  final servers = <ImportedProxy>[];
  final seen = <String>{};
  var skipped = 0;
  for (final entry in raw) {
    if (entry is! Map<String, dynamic>) {
      skipped++;
      continue;
    }
    final type = entry['type'];
    if (type is! String) {
      skipped++;
      continue;
    }
    if (_singboxServiceTypes.contains(type)) {
      continue;
    }
    final config = _mapSingboxOutbound(type, entry);
    if (config == null) {
      skipped++;
      continue;
    }
    if (seen.add(proxyDedupKey(config))) {
      servers.add(ImportedProxy(config: config, rawUrl: jsonEncode(entry)));
    } else {
      skipped++;
    }
  }
  return SubscriptionImport(
    servers: servers,
    skipped: skipped,
    format: SubscriptionFormat.singboxJson,
  );
}

ProxyConfig? _mapSingboxOutbound(String type, Map<String, dynamic> o) {
  final server = _asString(o['server']);
  final port = _asInt(o['server_port']);
  if (server == null || server.isEmpty || port == null) {
    return null;
  }
  final name = _asString(o['tag']) ?? server;
  switch (type) {
    case 'vless':
      return _singboxVless(o, server, port, name);
    case 'vmess':
      return _singboxVmess(o, server, port, name);
    case 'trojan':
      return _singboxTrojan(o, server, port, name);
    case 'shadowsocks':
      return _singboxShadowsocks(o, server, port, name);
    case 'hysteria2':
      return _singboxHysteria2(o, server, port, name);
    default:
      return null;
  }
}

ProxyConfig? _singboxVless(
  Map<String, dynamic> o,
  String server,
  int port,
  String name,
) {
  final uuid = _asString(o['uuid']);
  if (uuid == null || uuid.isEmpty) {
    return null;
  }
  final tls = _asMap(o['tls']);
  final reality = _asMap(tls?['reality']);
  final utls = _asMap(tls?['utls']);
  final transport = _asMap(o['transport']);
  final network = _asString(transport?['type']) ?? 'tcp';
  final hasReality = reality != null && reality['enabled'] == true;
  final security = hasReality
      ? 'reality'
      : (tls?['enabled'] == true ? 'tls' : 'none');
  return VlessConfig(
    host: server,
    port: port,
    name: name,
    uuid: uuid,
    transport: network,
    security: security,
    sni: _asString(tls?['server_name']),
    flow: _nonEmpty(_asString(o['flow'])),
    publicKey: _asString(reality?['public_key']),
    shortId: _asString(reality?['short_id']),
    fingerprint: _asString(utls?['fingerprint']),
    alpn: _asStringList(tls?['alpn']),
    wsPath: network == 'ws' ? _asString(transport?['path']) : null,
    wsHostHeader: _singboxWsHost(network, transport),
    grpcServiceName:
        network == 'grpc' ? _asString(transport?['service_name']) : null,
  );
}

ProxyConfig? _singboxVmess(
  Map<String, dynamic> o,
  String server,
  int port,
  String name,
) {
  final uuid = _asString(o['uuid']);
  if (uuid == null || uuid.isEmpty) {
    return null;
  }
  final tls = _asMap(o['tls']);
  final transport = _asMap(o['transport']);
  final network = _asString(transport?['type']) ?? 'tcp';
  return VmessConfig(
    host: server,
    port: port,
    name: name,
    uuid: uuid,
    alterId: _asInt(o['alter_id']) ?? 0,
    cipher: _nonEmpty(_asString(o['security'])) ?? 'auto',
    network: network,
    tls: tls?['enabled'] == true,
    sni: _asString(tls?['server_name']),
    alpn: _asStringList(tls?['alpn']),
    wsPath: network == 'ws' ? _asString(transport?['path']) : null,
    wsHostHeader: _singboxWsHost(network, transport),
  );
}

ProxyConfig? _singboxTrojan(
  Map<String, dynamic> o,
  String server,
  int port,
  String name,
) {
  final password = _asString(o['password']);
  if (password == null || password.isEmpty) {
    return null;
  }
  final tls = _asMap(o['tls']);
  final transport = _asMap(o['transport']);
  final network = _asString(transport?['type']) ?? 'tcp';
  return TrojanConfig(
    host: server,
    port: port,
    name: name,
    password: password,
    network: network,
    sni: _asString(tls?['server_name']),
    alpn: _asStringList(tls?['alpn']),
    wsPath: network == 'ws' ? _asString(transport?['path']) : null,
    wsHostHeader: _singboxWsHost(network, transport),
    allowInsecure: tls?['insecure'] == true,
  );
}

ProxyConfig? _singboxShadowsocks(
  Map<String, dynamic> o,
  String server,
  int port,
  String name,
) {
  final method = _asString(o['method']);
  final password = _asString(o['password']);
  if (method == null ||
      method.isEmpty ||
      password == null ||
      password.isEmpty) {
    return null;
  }
  return ShadowsocksConfig(
    host: server,
    port: port,
    name: name,
    method: method,
    password: password,
  );
}

ProxyConfig? _singboxHysteria2(
  Map<String, dynamic> o,
  String server,
  int port,
  String name,
) {
  final password = _asString(o['password']);
  if (password == null || password.isEmpty) {
    return null;
  }
  final tls = _asMap(o['tls']);
  final obfs = _asMap(o['obfs']);
  return Hysteria2Config(
    host: server,
    port: port,
    name: name,
    password: password,
    sni: _asString(tls?['server_name']),
    obfs: _asString(obfs?['type']),
    obfsPassword: _asString(obfs?['password']),
    allowInsecure: tls?['insecure'] == true,
  );
}

String? _singboxWsHost(String network, Map<String, dynamic>? transport) {
  if (network != 'ws') {
    return null;
  }
  return _asString(_asMap(transport?['headers'])?['Host']);
}

Map<String, dynamic>? _asMap(Object? value) =>
    value is Map<String, dynamic> ? value : null;

String? _asString(Object? value) => value is String ? value : null;

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

List<String> _asStringList(Object? value) =>
    value is List ? value.whereType<String>().toList() : const <String>[];

String? _nonEmpty(String? value) =>
    value == null || value.isEmpty ? null : value;
