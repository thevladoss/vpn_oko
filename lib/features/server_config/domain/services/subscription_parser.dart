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
