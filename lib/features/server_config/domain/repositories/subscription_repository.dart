import 'package:vpn_osin/features/server_config/domain/entities/server_profile.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription_import.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription_userinfo.dart';

abstract interface class SubscriptionRepository {
  Stream<List<Subscription>> watchAll();

  Future<Subscription> add(Subscription draft, List<ImportedProxy> servers);

  Future<void> updateMeta(
    int id,
    SubscriptionUserInfo info,
    DateTime lastUpdatedAt,
  );

  Future<List<ServerProfile>> serversFor(int id);

  Future<void> applyDiff(int subscriptionId, List<ImportedProxy> freshServers);

  Future<void> remove(int id);
}
