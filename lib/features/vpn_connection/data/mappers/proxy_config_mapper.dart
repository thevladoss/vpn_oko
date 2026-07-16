import 'package:vpn_osin/features/server_config/domain/entities/proxy_config.dart';
import 'package:vpn_osin/features/server_config/domain/services/singbox_config_builder.dart';
import 'package:vpn_osin/features/vpn_connection/domain/entities/vpn_config.dart';

VpnConfig proxyConfigToVpnConfig(ProxyConfig config) => VpnConfig(
  host: config.host,
  port: config.port,
  userId: '',
  serverName: config.name,
  singboxConfigJson: toSingboxJson(config),
);
