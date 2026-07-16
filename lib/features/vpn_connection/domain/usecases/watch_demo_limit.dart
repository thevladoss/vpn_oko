import 'package:vpn_osin/features/vpn_connection/domain/entities/demo_limit.dart';
import 'package:vpn_osin/features/vpn_connection/domain/repositories/vpn_repository.dart';

class WatchDemoLimit {
  const WatchDemoLimit(this._repository);

  final VpnRepository _repository;

  Stream<DemoExpiry> call() => _repository.watchDemoLimit();
}
