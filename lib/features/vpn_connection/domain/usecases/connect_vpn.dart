import 'package:vpn_osin/features/vpn_connection/domain/entities/vpn_config.dart';
import 'package:vpn_osin/features/vpn_connection/domain/repositories/vpn_repository.dart';

class ConnectVpn {
  const ConnectVpn(this._repository);

  final VpnRepository _repository;

  Future<void> call(VpnConfig config) => _repository.connect(config);
}
