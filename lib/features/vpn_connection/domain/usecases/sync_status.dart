import 'package:vpn_oko/features/vpn_connection/domain/repositories/vpn_repository.dart';

class SyncStatus {
  const SyncStatus(this._repository);

  final VpnRepository _repository;

  Future<void> call() => _repository.syncStatus();
}
