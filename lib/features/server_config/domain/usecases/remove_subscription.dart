import 'package:vpn_osin/features/server_config/domain/repositories/subscription_repository.dart';

class RemoveSubscription {
  const RemoveSubscription(this._repository);

  final SubscriptionRepository _repository;

  Future<void> call(int id) => _repository.remove(id);
}
