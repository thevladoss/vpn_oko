import 'dart:async';

import 'package:flutter/services.dart';
import 'package:vpn_oko/core/bridge/vpn_api.g.dart';
import 'package:vpn_oko/core/error/vpn_exception.dart';
import 'package:vpn_oko/features/vpn_connection/data/datasources/vpn_native_datasource.dart';
import 'package:vpn_oko/features/vpn_connection/data/mappers/vpn_event_mapper.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/demo_limit.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/traffic_stats.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/vpn_config.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/vpn_state.dart';
import 'package:vpn_oko/features/vpn_connection/domain/repositories/vpn_repository.dart';

class VpnRepositoryImpl implements VpnRepository {
  VpnRepositoryImpl(this._ds) {
    _subscription = _ds.states.listen(_onState);
    _demoSubscription = _ds.demoLimit.listen(_demoController.add);
  }

  final VpnNativeDatasource _ds;
  final StreamController<VpnState> _controller =
      StreamController<VpnState>.broadcast();
  final StreamController<DemoExpiry> _demoController =
      StreamController<DemoExpiry>.broadcast();
  late final StreamSubscription<VpnState> _subscription;
  late final StreamSubscription<DemoExpiry> _demoSubscription;
  VpnState _last = const VpnDisconnected();

  void _onState(VpnState state) {
    _last = state;
    _controller.add(state);
  }

  @override
  Stream<VpnState> watchState() {
    late final StreamController<VpnState> output;
    StreamSubscription<VpnState>? forwarding;
    output = StreamController<VpnState>(
      onListen: () {
        forwarding = _controller.stream.listen(
          output.add,
          onError: output.addError,
          onDone: output.close,
        );
        output.add(_last);
      },
      onCancel: () => forwarding?.cancel(),
    );
    return output.stream;
  }

  @override
  Stream<TrafficStats> watchTraffic() => _ds.traffic;

  @override
  Stream<DemoExpiry> watchDemoLimit() => _demoController.stream;

  @override
  Future<void> connect(VpnConfig config) async {
    try {
      await _ds.start(
        VpnConfigMessage(
          host: config.host,
          port: config.port,
          userId: config.userId,
          serverName: config.serverName,
          singboxConfigJson: config.singboxConfigJson,
        ),
      );
    } on PlatformException catch (exception) {
      throw mapPlatformException(exception);
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _ds.stop();
    } on PlatformException catch (exception) {
      throw mapPlatformException(exception);
    }
  }

  @override
  Future<void> syncStatus() async {
    try {
      final snapshot = await _ds.currentStatus();
      _last = snapshotToEntity(snapshot);
      _controller.add(_last);
      final demo = snapshotToDemo(snapshot);
      if (demo != null) {
        _demoController.add(demo);
      }
    } on PlatformException catch (exception) {
      throw mapPlatformException(exception);
    }
  }

  @override
  Future<void> dispose() async {
    await _subscription.cancel();
    await _demoSubscription.cancel();
    await _controller.close();
    await _demoController.close();
  }
}
