import 'package:vpn_oko/features/vpn_connection/domain/entities/traffic_stats.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/vpn_config.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/vpn_state.dart';

abstract interface class VpnRepository {
  Stream<VpnState> watchState();
  Stream<TrafficStats> watchTraffic();
  Future<void> connect(VpnConfig config);
  Future<void> disconnect();
  Future<void> syncStatus();
  Future<void> dispose();
}
