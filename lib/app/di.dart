import 'package:vpn_oko/core/bridge/vpn_api.g.dart';
import 'package:vpn_oko/core/bridge/vpn_bridge.dart';
import 'package:vpn_oko/features/vpn_connection/data/datasources/vpn_native_datasource.dart';
import 'package:vpn_oko/features/vpn_connection/data/repositories/vpn_repository_impl.dart';
import 'package:vpn_oko/features/vpn_connection/domain/repositories/vpn_repository.dart';
import 'package:vpn_oko/features/vpn_connection/domain/usecases/connect_vpn.dart';
import 'package:vpn_oko/features/vpn_connection/domain/usecases/disconnect_vpn.dart';
import 'package:vpn_oko/features/vpn_connection/domain/usecases/sync_status.dart';
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
    connectVpn = ConnectVpn(vpnRepository);
    disconnectVpn = DisconnectVpn(vpnRepository);
    syncStatus = SyncStatus(vpnRepository);
    watchLogs = WatchLogs(logRepository);
  }

  final VpnBridge _bridge;

  late final VpnRepository vpnRepository;
  late final LogRepository logRepository;
  late final WatchVpnState watchVpnState;
  late final ConnectVpn connectVpn;
  late final DisconnectVpn disconnectVpn;
  late final SyncStatus syncStatus;
  late final WatchLogs watchLogs;

  Future<void> dispose() async {
    await vpnRepository.dispose();
    await logRepository.dispose();
    await _bridge.dispose();
  }
}
