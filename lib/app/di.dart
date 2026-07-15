import 'package:vpn_oko/core/bridge/vpn_api.g.dart';
import 'package:vpn_oko/core/bridge/vpn_bridge.dart';
import 'package:vpn_oko/features/server_config/data/datasources/clipboard_source_impl.dart';
import 'package:vpn_oko/features/server_config/data/probes/socket_latency_probe.dart';
import 'package:vpn_oko/features/server_config/domain/repositories/clipboard_source.dart';
import 'package:vpn_oko/features/server_config/domain/repositories/latency_probe.dart';
import 'package:vpn_oko/features/vpn_connection/data/datasources/vpn_native_datasource.dart';
import 'package:vpn_oko/features/vpn_connection/data/repositories/vpn_repository_impl.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/vpn_config.dart';
import 'package:vpn_oko/features/vpn_connection/domain/repositories/vpn_repository.dart';
import 'package:vpn_oko/features/vpn_connection/domain/usecases/connect_vpn.dart';
import 'package:vpn_oko/features/vpn_connection/domain/usecases/disconnect_vpn.dart';
import 'package:vpn_oko/features/vpn_connection/domain/usecases/sync_status.dart';
import 'package:vpn_oko/features/vpn_connection/domain/usecases/watch_demo_limit.dart';
import 'package:vpn_oko/features/vpn_connection/domain/usecases/watch_traffic.dart';
import 'package:vpn_oko/features/vpn_connection/domain/usecases/watch_vpn_state.dart';
import 'package:vpn_oko/features/vpn_logs/data/datasources/log_native_datasource.dart';
import 'package:vpn_oko/features/vpn_logs/data/repositories/log_repository_impl.dart';
import 'package:vpn_oko/features/vpn_logs/domain/repositories/log_repository.dart';
import 'package:vpn_oko/features/vpn_logs/domain/usecases/watch_logs.dart';

class AppDependencies {
  AppDependencies()
      : _bridge = VpnBridge(hostApi: VpnHostApi(), events: vpnEvents()) {
    final vpnDatasource = VpnNativeDatasource(_bridge);
    final logDatasource = LogNativeDatasource(_bridge);
    vpnRepository = VpnRepositoryImpl(vpnDatasource);
    logRepository = LogRepositoryImpl(logDatasource);
    watchVpnState = WatchVpnState(vpnRepository);
    watchTraffic = WatchTraffic(vpnRepository);
    watchDemoLimit = WatchDemoLimit(vpnRepository);
    connectVpn = ConnectVpn(vpnRepository);
    disconnectVpn = DisconnectVpn(vpnRepository);
    syncStatus = SyncStatus(vpnRepository);
    watchLogs = WatchLogs(logRepository);
  }

  final VpnBridge _bridge;

  late final VpnRepository vpnRepository;
  late final LogRepository logRepository;
  late final WatchVpnState watchVpnState;
  late final WatchTraffic watchTraffic;
  late final WatchDemoLimit watchDemoLimit;
  late final ConnectVpn connectVpn;
  late final DisconnectVpn disconnectVpn;
  late final SyncStatus syncStatus;
  late final WatchLogs watchLogs;

  final VpnConfig demoConfig = const VpnConfig(
    host: 'echo.oko.vpn',
    port: 443,
    userId: '00000000-0000-0000-0000-000000000000',
    serverName: 'Echo Server',
    singboxConfigJson: '',
  );

  final ClipboardSource clipboardSource = const SystemClipboardSource();
  final LatencyProbe latencyProbe = const SocketLatencyProbe();

  Future<void> dispose() async {
    await vpnRepository.dispose();
    await logRepository.dispose();
    await _bridge.dispose();
  }
}
