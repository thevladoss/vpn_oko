import 'package:vpn_osin/core/bridge/vpn_api.g.dart';
import 'package:vpn_osin/core/bridge/vpn_bridge.dart';
import 'package:vpn_osin/features/vpn_connection/data/mappers/vpn_event_mapper.dart';
import 'package:vpn_osin/features/vpn_connection/domain/entities/demo_limit.dart';
import 'package:vpn_osin/features/vpn_connection/domain/entities/traffic_stats.dart';
import 'package:vpn_osin/features/vpn_connection/domain/entities/vpn_state.dart';

class VpnNativeDatasource {
  VpnNativeDatasource(this._bridge);

  final VpnBridge _bridge;

  Stream<VpnState> get states => _bridge.statusEvents.map(statusToEntity);

  Stream<TrafficStats> get traffic =>
      _bridge.trafficEvents.map(trafficToEntity);

  Stream<DemoExpiry> get demoLimit => _bridge.demoEvents.map(demoToEntity);

  Future<VpnStatusSnapshotMessage> currentStatus() => _bridge.getStatus();

  Future<void> start(VpnConfigMessage config) => _bridge.startVpn(config);

  Future<void> stop() => _bridge.stopVpn();
}
