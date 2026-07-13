import 'dart:async';

import 'package:flutter/services.dart';
import 'package:vpn_oko/core/bridge/vpn_api.g.dart';
import 'package:vpn_oko/features/vpn_connection/data/datasources/vpn_native_datasource.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/traffic_stats.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/vpn_state.dart';

class FakeVpnNativeDatasource implements VpnNativeDatasource {
  final StreamController<VpnState> _states =
      StreamController<VpnState>.broadcast();
  final StreamController<TrafficStats> _traffic =
      StreamController<TrafficStats>.broadcast();

  final List<VpnConfigMessage> startedWith = <VpnConfigMessage>[];
  int stopCount = 0;

  PlatformException? startError;
  PlatformException? stopError;
  PlatformException? statusError;

  VpnStatusSnapshotMessage snapshot = VpnStatusSnapshotMessage(
    status: VpnStatusMessage.disconnected,
    rxBytes: 0,
    txBytes: 0,
  );

  void emitState(VpnState state) => _states.add(state);

  void emitTraffic(TrafficStats stats) => _traffic.add(stats);

  @override
  Stream<VpnState> get states => _states.stream;

  @override
  Stream<TrafficStats> get traffic => _traffic.stream;

  @override
  Future<VpnStatusSnapshotMessage> currentStatus() async {
    final error = statusError;
    if (error != null) {
      throw error;
    }
    return snapshot;
  }

  @override
  Future<void> start(VpnConfigMessage config) async {
    final error = startError;
    if (error != null) {
      throw error;
    }
    startedWith.add(config);
  }

  @override
  Future<void> stop() async {
    final error = stopError;
    if (error != null) {
      throw error;
    }
    stopCount++;
  }

  Future<void> dispose() async {
    await _states.close();
    await _traffic.close();
  }
}
