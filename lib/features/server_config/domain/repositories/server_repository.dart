import 'package:vpn_osin/features/server_config/domain/entities/add_server_outcome.dart';
import 'package:vpn_osin/features/server_config/domain/entities/proxy_config.dart';
import 'package:vpn_osin/features/server_config/domain/entities/server_profile.dart';

abstract interface class ServerRepository {
  Stream<List<ServerProfile>> watchAll();

  Stream<ServerProfile?> watchActive();

  Future<ServerProfile?> getActive();

  Future<AddServerOutcome> add(ProxyConfig config, String rawUrl);

  Future<void> setActive(int id);

  Future<void> rename(int id, String label);

  Future<void> delete(int id);
}
