import 'package:vpn_osin/features/server_config/domain/entities/server_profile.dart';
import 'package:vpn_osin/features/server_config/domain/repositories/settings_repository.dart';
import 'package:vpn_osin/features/server_config/domain/repositories/subscription_repository.dart';
import 'package:vpn_osin/features/vpn_connection/data/mappers/proxy_config_mapper.dart';
import 'package:vpn_osin/features/vpn_connection/domain/entities/vpn_config.dart';

class ResolveActiveVpnConfig {
  const ResolveActiveVpnConfig(this._settings, this._subscriptions);

  final SettingsRepository _settings;
  final SubscriptionRepository _subscriptions;

  Future<VpnConfig?> call(ServerProfile? active) async {
    if (active == null) {
      return null;
    }
    final subscriptionId = active.subscriptionId;
    if (subscriptionId != null && await _settings.autoSwitchEnabled()) {
      final servers = await _subscriptions.serversFor(subscriptionId);
      final configs = servers.map((server) => server.config).toList();
      if (configs.length > 1) {
        return autoSwitchConfigToVpnConfig(active, configs);
      }
    }
    return proxyConfigToVpnConfig(active.config);
  }
}
