import 'package:vpn_osin/features/server_config/domain/entities/proxy_config.dart';
import 'package:vpn_osin/features/server_config/domain/entities/server_profile.dart';
import 'package:vpn_osin/features/server_config/domain/services/singbox_config_builder.dart';
import 'package:vpn_osin/features/vpn_connection/domain/entities/vpn_config.dart';

VpnConfig proxyConfigToVpnConfig(ProxyConfig config) => VpnConfig(
  host: config.host,
  port: config.port,
  userId: '',
  serverName: config.name,
  singboxConfigJson: toSingboxJson(config),
);

VpnConfig autoSwitchConfigToVpnConfig(
  ServerProfile active,
  List<ProxyConfig> configs,
) => VpnConfig(
  host: active.config.host,
  port: active.config.port,
  userId: '',
  serverName: active.config.name,
  singboxConfigJson: toAutoSwitchJson(configs),
);
