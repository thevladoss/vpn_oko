import 'package:drift/drift.dart';
import 'package:vpn_osin/features/server_config/data/local/app_database.dart';
import 'package:vpn_osin/features/server_config/domain/entities/proxy_config.dart';
import 'package:vpn_osin/features/server_config/domain/entities/proxy_parse_result.dart';
import 'package:vpn_osin/features/server_config/domain/entities/server_profile.dart';
import 'package:vpn_osin/features/server_config/domain/services/proxy_parser.dart';

String protocolOf(ProxyConfig config) => switch (config) {
  VlessConfig() => 'vless',
  VmessConfig() => 'vmess',
  TrojanConfig() => 'trojan',
  ShadowsocksConfig() => 'shadowsocks',
  Hysteria2Config() => 'hysteria2',
};

ServerProfile rowToProfile(ServerRow row) {
  final parsed = parseProxyUrl(row.rawUrl);
  return switch (parsed) {
    ProxyParsed(:final config) => ServerProfile(
      id: row.id,
      label: row.label,
      config: config,
      rawUrl: row.rawUrl,
      createdAt: row.createdAt,
      subscriptionId: row.subscriptionId,
    ),
    ProxyParseFailure() => throw StateError('corrupt server row'),
  };
}

ServerProfilesCompanion profileToCompanion(
  ProxyConfig config,
  String rawUrl, {
  int? subscriptionId,
  int sortOrder = 0,
}) => ServerProfilesCompanion.insert(
  label: config.name,
  rawUrl: rawUrl,
  protocol: protocolOf(config),
  host: config.host,
  port: config.port,
  createdAt: DateTime.now(),
  subscriptionId: Value(subscriptionId),
  sortOrder: Value(sortOrder),
);
