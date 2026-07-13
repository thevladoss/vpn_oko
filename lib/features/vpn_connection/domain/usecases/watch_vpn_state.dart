import 'package:vpn_oko/features/vpn_connection/domain/entities/vpn_state.dart';
import 'package:vpn_oko/features/vpn_connection/domain/repositories/vpn_repository.dart';

class WatchVpnState {
  const WatchVpnState(this._repository);

  final VpnRepository _repository;

  Stream<VpnState> call() => _repository.watchState();
}
