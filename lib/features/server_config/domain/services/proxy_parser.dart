import 'dart:convert';

import 'package:vpn_oko/features/server_config/domain/entities/proxy_config.dart';
import 'package:vpn_oko/features/server_config/domain/entities/proxy_parse_result.dart';
import 'package:vpn_oko/features/server_config/domain/entities/vless_parse_result.dart';
import 'package:vpn_oko/features/server_config/domain/services/vless_parser.dart';

ProxyParseResult parseProxyUrl(String input) {
  final raw = input.trim();
  if (raw.isEmpty) {
    return const ProxyParseFailure(ProxyParseError.empty);
  }
  final schemeEnd = raw.indexOf('://');
  if (schemeEnd <= 0) {
    return const ProxyParseFailure(ProxyParseError.unsupported);
  }
  final scheme = raw.substring(0, schemeEnd).toLowerCase();
  switch (scheme) {
    case 'vless':
      return _mapVless(parseVless(raw));
    case 'vmess':
      return _parseVmess(raw);
    case 'trojan':
      return _parseTrojan(raw);
    case 'ss':
      return _parseShadowsocks(raw);
    case 'hysteria2':
    case 'hy2':
      return _parseHysteria2(raw);
    default:
      return const ProxyParseFailure(ProxyParseError.unsupported);
  }
}

ProxyParseResult _mapVless(VlessParseResult result) {
  switch (result) {
    case VlessParsed(:final config):
      return ProxyParsed(config);
    case VlessParseFailure(:final error):
      final mapped = error == VlessError.empty
          ? ProxyParseError.empty
          : ProxyParseError.malformed;
      return ProxyParseFailure(mapped, error.name);
  }
}

ProxyParseResult _parseVmess(String raw) {
  final encoded = raw.substring('vmess://'.length);
  final Map<String, dynamic> json;
  try {
    final decoded = utf8.decode(base64.decode(base64.normalize(encoded)));
    final parsed = jsonDecode(decoded);
    if (parsed is! Map<String, dynamic>) {
      return const ProxyParseFailure(ProxyParseError.malformed);
    }
    json = parsed;
  } on FormatException {
    return const ProxyParseFailure(ProxyParseError.malformed);
  }

  final host = _asString(json['add']);
  final id = _asString(json['id']);
  if (host == null || host.isEmpty || id == null || id.isEmpty) {
    return const ProxyParseFailure(ProxyParseError.missingField);
  }
  final port = int.tryParse(_asString(json['port']) ?? '');
  if (port == null || port < 1 || port > 65535) {
    return const ProxyParseFailure(ProxyParseError.malformed);
  }

  return ProxyParsed(
    VmessConfig(
      host: host,
      port: port,
      name: _nonEmpty(_asString(json['ps'])) ?? host,
      uuid: id,
      alterId: int.tryParse(_asString(json['aid']) ?? '') ?? 0,
      cipher: _nonEmpty(_asString(json['scy'])) ?? 'auto',
      network: _nonEmpty(_asString(json['net'])) ?? 'tcp',
      tls: _asString(json['tls']) == 'tls',
      sni: _nonEmpty(_asString(json['sni'])),
      alpn: _splitAlpn(_asString(json['alpn'])),
      wsPath: _nonEmpty(_asString(json['path'])),
      wsHostHeader: _nonEmpty(_asString(json['host'])),
    ),
  );
}

ProxyParseResult _parseTrojan(String raw) {
  final Uri uri;
  try {
    uri = Uri.parse(raw);
  } on FormatException {
    return const ProxyParseFailure(ProxyParseError.malformed);
  }
  final password = uri.userInfo;
  if (password.isEmpty || uri.host.isEmpty) {
    return const ProxyParseFailure(ProxyParseError.missingField);
  }
  if (!uri.hasPort || uri.port < 1 || uri.port > 65535) {
    return const ProxyParseFailure(ProxyParseError.malformed);
  }
  try {
    final q = uri.queryParameters;
    return ProxyParsed(
      TrojanConfig(
        host: uri.host,
        port: uri.port,
        name: _fragmentName(uri),
        password: password,
        network: q['type'] ?? 'tcp',
        sni: _nonEmpty(q['sni']),
        alpn: _splitAlpn(q['alpn']),
        wsPath: _nonEmpty(q['path']),
        wsHostHeader: _nonEmpty(q['host']),
        allowInsecure: _isTruthy(q['allowInsecure'] ?? q['insecure']),
      ),
    );
  } on FormatException {
    return const ProxyParseFailure(ProxyParseError.malformed);
  }
}

ProxyParseResult _parseHysteria2(String raw) {
  final normalized = raw.startsWith('hy2://')
      ? 'hysteria2://${raw.substring('hy2://'.length)}'
      : raw;
  final Uri uri;
  try {
    uri = Uri.parse(normalized);
  } on FormatException {
    return const ProxyParseFailure(ProxyParseError.malformed);
  }
  final password = uri.userInfo;
  if (password.isEmpty || uri.host.isEmpty) {
    return const ProxyParseFailure(ProxyParseError.missingField);
  }
  if (!uri.hasPort || uri.port < 1 || uri.port > 65535) {
    return const ProxyParseFailure(ProxyParseError.malformed);
  }
  try {
    final q = uri.queryParameters;
    return ProxyParsed(
      Hysteria2Config(
        host: uri.host,
        port: uri.port,
        name: _fragmentName(uri),
        password: password,
        sni: _nonEmpty(q['sni']),
        obfs: _nonEmpty(q['obfs']),
        obfsPassword: _nonEmpty(q['obfs-password']),
        allowInsecure: _isTruthy(q['insecure']),
      ),
    );
  } on FormatException {
    return const ProxyParseFailure(ProxyParseError.malformed);
  }
}

ProxyParseResult _parseShadowsocks(String raw) {
  final afterScheme = raw.substring('ss://'.length);
  final hashIndex = afterScheme.indexOf('#');
  final name = hashIndex >= 0
      ? _decodeFragment(afterScheme.substring(hashIndex + 1))
      : null;
  final body = hashIndex >= 0
      ? afterScheme.substring(0, hashIndex)
      : afterScheme;

  final atIndex = body.lastIndexOf('@');
  if (atIndex > 0) {
    final userInfo = body.substring(0, atIndex);
    final rest = body.substring(atIndex + 1);
    final queryIndex = rest.indexOf('?');
    final hostPort = queryIndex >= 0 ? rest.substring(0, queryIndex) : rest;
    final methodPassword = _tryDecodeBase64(userInfo);
    if (methodPassword != null) {
      final result = _buildShadowsocks(methodPassword, hostPort, name);
      if (result != null) {
        return result;
      }
    }
  }

  final decoded = _tryDecodeBase64(body);
  if (decoded != null) {
    final at = decoded.lastIndexOf('@');
    if (at > 0) {
      final result = _buildShadowsocks(
        decoded.substring(0, at),
        decoded.substring(at + 1),
        name,
      );
      if (result != null) {
        return result;
      }
    }
  }

  return const ProxyParseFailure(ProxyParseError.malformed);
}

ProxyParseResult? _buildShadowsocks(
  String methodPassword,
  String hostPort,
  String? name,
) {
  final colon = methodPassword.indexOf(':');
  if (colon <= 0) {
    return null;
  }
  final endpoint = _splitHostPort(hostPort);
  if (endpoint == null) {
    return null;
  }
  return ProxyParsed(
    ShadowsocksConfig(
      host: endpoint.$1,
      port: endpoint.$2,
      name: name ?? endpoint.$1,
      method: methodPassword.substring(0, colon),
      password: methodPassword.substring(colon + 1),
    ),
  );
}

(String, int)? _splitHostPort(String value) {
  final colon = value.lastIndexOf(':');
  if (colon <= 0) {
    return null;
  }
  final host = value.substring(0, colon);
  final port = int.tryParse(value.substring(colon + 1));
  if (host.isEmpty || port == null || port < 1 || port > 65535) {
    return null;
  }
  return (host, port);
}

String? _tryDecodeBase64(String value) {
  try {
    return utf8.decode(base64.decode(base64.normalize(value)));
  } on FormatException {
    return null;
  }
}

String _fragmentName(Uri uri) =>
    uri.fragment.isEmpty ? uri.host : Uri.decodeComponent(uri.fragment);

String _decodeFragment(String fragment) {
  try {
    return Uri.decodeComponent(fragment);
  } on FormatException {
    return fragment;
  }
}

String? _asString(Object? value) => value?.toString();

String? _nonEmpty(String? value) =>
    value == null || value.isEmpty ? null : value;

List<String> _splitAlpn(String? value) => (value ?? '')
    .split(',')
    .where((e) => e.isNotEmpty)
    .toList();

bool _isTruthy(String? value) => value == '1' || value == 'true';
