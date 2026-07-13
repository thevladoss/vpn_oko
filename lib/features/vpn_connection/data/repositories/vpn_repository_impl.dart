import 'dart:async';

import 'package:flutter/services.dart';
import 'package:vpn_oko/core/bridge/vpn_api.g.dart';
import 'package:vpn_oko/core/error/vpn_exception.dart';
import 'package:vpn_oko/features/vpn_connection/data/datasources/vpn_native_datasource.dart';
import 'package:vpn_oko/features/vpn_connection/data/mappers/vpn_event_mapper.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/traffic_stats.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/vpn_config.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/vpn_state.dart';
import 'package:vpn_oko/features/vpn_connection/domain/repositories/vpn_repository.dart';

class VpnRepositoryImpl implements VpnRepository {
  VpnRepositoryImpl(this._ds) {
    _subscription = _ds.states.listen(_onState);
  }

  final VpnNativeDatasource _ds;
  final StreamController<VpnState> _controller =
      StreamController<VpnState>.broadcast();
  late final StreamSubscription<VpnState> _subscription;
  VpnState _last = const VpnDisconnected();

  void _onState(VpnState state) {
    _last = state;
    _controller.add(state);
  }

  @override
  Stream<VpnState> watchState() async* {
    yield _last;
    yield* _controller.stream;
  }

  @override
  Stream<TrafficStats> watchTraffic() => _ds.traffic;

  @override
  Future<void> connect(VpnConfig config) async {
    try {
      await _ds.start(
        VpnConfigMessage(
          host: config.host,
          port: config.port,
          userId: config.userId,
          serverName: config.serverName,
        ),
      );
    } on PlatformException catch (exception) {
      throw mapPlatformException(exception);
    }
  }

  @override
  Future<void> disconnect() => _ds.stop();

  @override
  Future<void> syncStatus() async {
    _last = snapshotToEntity(await _ds.currentStatus());
    _controller.add(_last);
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _controller.close();
  }
}
