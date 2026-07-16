import 'package:vpn_osin/features/vpn_connection/domain/entities/traffic_stats.dart';
import 'package:vpn_osin/features/vpn_connection/domain/repositories/vpn_repository.dart';

class WatchTraffic {
  const WatchTraffic(this._repository);

  final VpnRepository _repository;

  Stream<TrafficStats> call() => _repository.watchTraffic();
}
