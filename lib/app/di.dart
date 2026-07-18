import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:vpn_osin/core/bridge/vpn_api.g.dart';
import 'package:vpn_osin/core/bridge/vpn_bridge.dart';
import 'package:vpn_osin/features/server_config/data/datasources/clipboard_source_impl.dart';
import 'package:vpn_osin/features/server_config/data/datasources/subscription_remote.dart';
import 'package:vpn_osin/features/server_config/data/local/app_database.dart';
import 'package:vpn_osin/features/server_config/data/local/encrypted_database.dart';
import 'package:vpn_osin/features/server_config/data/local/secret_key_store.dart';
import 'package:vpn_osin/features/server_config/data/probes/socket_latency_probe.dart';
import 'package:vpn_osin/features/server_config/data/repositories/drift_server_repository.dart';
import 'package:vpn_osin/features/server_config/data/repositories/drift_settings_repository.dart';
import 'package:vpn_osin/features/server_config/data/repositories/drift_subscription_repository.dart';
import 'package:vpn_osin/features/server_config/domain/repositories/clipboard_source.dart';
import 'package:vpn_osin/features/server_config/domain/repositories/latency_probe.dart';
import 'package:vpn_osin/features/server_config/domain/repositories/server_repository.dart';
import 'package:vpn_osin/features/server_config/domain/repositories/settings_repository.dart';
import 'package:vpn_osin/features/server_config/domain/repositories/subscription_repository.dart';
import 'package:vpn_osin/features/server_config/domain/usecases/add_subscription.dart';
import 'package:vpn_osin/features/server_config/domain/usecases/refresh_subscription.dart';
import 'package:vpn_osin/features/server_config/domain/usecases/remove_subscription.dart';
import 'package:vpn_osin/features/vpn_connection/data/datasources/vpn_native_datasource.dart';
import 'package:vpn_osin/features/vpn_connection/data/repositories/vpn_repository_impl.dart';
import 'package:vpn_osin/features/vpn_connection/domain/repositories/vpn_repository.dart';
import 'package:vpn_osin/features/vpn_connection/domain/usecases/connect_vpn.dart';
import 'package:vpn_osin/features/vpn_connection/domain/usecases/disconnect_vpn.dart';
import 'package:vpn_osin/features/vpn_connection/domain/usecases/resolve_active_vpn_config.dart';
import 'package:vpn_osin/features/vpn_connection/domain/usecases/sync_status.dart';
import 'package:vpn_osin/features/vpn_connection/domain/usecases/watch_traffic.dart';
import 'package:vpn_osin/features/vpn_connection/domain/usecases/watch_vpn_state.dart';

class AppDependencies {
  AppDependencies()
      : _bridge = VpnBridge(hostApi: VpnHostApi(), events: vpnEvents()) {
    final vpnDatasource = VpnNativeDatasource(_bridge);
    vpnRepository = VpnRepositoryImpl(vpnDatasource);
    watchVpnState = WatchVpnState(vpnRepository);
    watchTraffic = WatchTraffic(vpnRepository);
    connectVpn = ConnectVpn(vpnRepository);
    disconnectVpn = DisconnectVpn(vpnRepository);
    syncStatus = SyncStatus(vpnRepository);
    const keyStore = SecretKeyStore(
      FlutterSecretStore(FlutterSecureStorage()),
    );
    _database = openEncryptedDatabase(keyStore);
    serverRepository = DriftServerRepository(_database);
    final subscriptionRemote = SubscriptionRemote(_httpClient);
    subscriptionRepository = DriftSubscriptionRepository(_database);
    settingsRepository = DriftSettingsRepository(_database);
    resolveActiveVpnConfig = ResolveActiveVpnConfig(
      settingsRepository,
      subscriptionRepository,
    );
    addSubscription =
        AddSubscription(subscriptionRemote, subscriptionRepository);
    refreshSubscription =
        RefreshSubscription(subscriptionRemote, subscriptionRepository);
    removeSubscription = RemoveSubscription(subscriptionRepository);
  }

  final VpnBridge _bridge;
  late final AppDatabase _database;
  final http.Client _httpClient = http.Client();

  late final VpnRepository vpnRepository;
  late final ServerRepository serverRepository;
  late final SubscriptionRepository subscriptionRepository;
  late final SettingsRepository settingsRepository;
  late final ResolveActiveVpnConfig resolveActiveVpnConfig;
  late final AddSubscription addSubscription;
  late final RefreshSubscription refreshSubscription;
  late final RemoveSubscription removeSubscription;
  late final WatchVpnState watchVpnState;
  late final WatchTraffic watchTraffic;
  late final ConnectVpn connectVpn;
  late final DisconnectVpn disconnectVpn;
  late final SyncStatus syncStatus;

  final ClipboardSource clipboardSource = const SystemClipboardSource();
  final LatencyProbe latencyProbe = const SocketLatencyProbe();

  Future<void> dispose() async {
    await vpnRepository.dispose();
    await _bridge.dispose();
    _httpClient.close();
    await _database.close();
  }
}
