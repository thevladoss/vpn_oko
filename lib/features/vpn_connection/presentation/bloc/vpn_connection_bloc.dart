import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn_oko/core/error/failures.dart';
import 'package:vpn_oko/core/theme/vpn_status.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/traffic_stats.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/vpn_config.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/vpn_state.dart';
import 'package:vpn_oko/features/vpn_connection/domain/usecases/connect_vpn.dart';
import 'package:vpn_oko/features/vpn_connection/domain/usecases/disconnect_vpn.dart';
import 'package:vpn_oko/features/vpn_connection/domain/usecases/sync_status.dart';
import 'package:vpn_oko/features/vpn_connection/domain/usecases/watch_traffic.dart';
import 'package:vpn_oko/features/vpn_connection/domain/usecases/watch_vpn_state.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/bloc/vpn_connection_event.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/bloc/vpn_connection_state.dart';

class VpnConnectionBloc extends Bloc<VpnConnectionEvent, VpnConnectionState> {
  VpnConnectionBloc({
    required this.watchVpnState,
    required this.watchTraffic,
    required this.connectVpn,
    required this.disconnectVpn,
    required this.syncStatus,
    required VpnConfig config,
  }) : _activeConfig = config,
       super(const VpnConnectionState(status: VpnStatus.disconnected)) {
    on<VpnStarted>(_onStarted);
    on<VpnStateReceived>(_onStateReceived);
    on<VpnTrafficReceived>(_onTrafficReceived);
    on<ConfigSelected>(_onConfigSelected);
    on<ConnectRequested>(_onConnectRequested);
    on<DisconnectRequested>(_onDisconnectRequested);
  }

  final WatchVpnState watchVpnState;
  final WatchTraffic watchTraffic;
  final ConnectVpn connectVpn;
  final DisconnectVpn disconnectVpn;
  final SyncStatus syncStatus;

  VpnConfig _activeConfig;

  VpnConfig get config => _activeConfig;

  StreamSubscription<VpnState>? _stateSub;
  StreamSubscription<TrafficStats>? _trafficSub;

  Future<void> _onStarted(
    VpnStarted event,
    Emitter<VpnConnectionState> emit,
  ) async {
    try {
      await syncStatus();
    } on Failure catch (failure) {
      emit(
        state.copyWith(
          status: VpnStatus.error,
          errorMessage: switch (failure) {
            VpnStartFailure(:final message) => message,
          },
          clearConnectedSince: true,
        ),
      );
    }
    await _stateSub?.cancel();
    await _trafficSub?.cancel();
    _stateSub = watchVpnState().listen((s) => add(VpnStateReceived(s)));
    _trafficSub = watchTraffic().listen((t) => add(VpnTrafficReceived(t)));
  }

  void _onStateReceived(
    VpnStateReceived event,
    Emitter<VpnConnectionState> emit,
  ) {
    emit(_map(event.state));
  }

  void _onTrafficReceived(
    VpnTrafficReceived event,
    Emitter<VpnConnectionState> emit,
  ) {
    emit(
      state.copyWith(
        rxBytes: event.stats.rxBytes,
        txBytes: event.stats.txBytes,
      ),
    );
  }

  void _onConfigSelected(
    ConfigSelected event,
    Emitter<VpnConnectionState> emit,
  ) {
    _activeConfig = event.config;
  }

  void _onConnectRequested(
    ConnectRequested event,
    Emitter<VpnConnectionState> emit,
  ) {
    if (state.isBusy) return;
    unawaited(connectVpn(_activeConfig));
  }

  void _onDisconnectRequested(
    DisconnectRequested event,
    Emitter<VpnConnectionState> emit,
  ) {
    if (state.isBusy) return;
    unawaited(disconnectVpn());
  }

  VpnConnectionState _map(VpnState domain) {
    return switch (domain) {
      VpnDisconnected() => state.copyWith(
        status: VpnStatus.disconnected,
        rxBytes: 0,
        txBytes: 0,
        clearConnectedSince: true,
        clearError: true,
      ),
      VpnConnecting() => state.copyWith(
        status: VpnStatus.connecting,
        rxBytes: 0,
        txBytes: 0,
        clearConnectedSince: true,
        clearError: true,
      ),
      VpnConnected(:final connectedSince) => state.copyWith(
        status: VpnStatus.connected,
        connectedSince: connectedSince,
        clearConnectedSince: connectedSince == null,
        clearError: true,
      ),
      VpnDisconnecting() => state.copyWith(
        status: VpnStatus.disconnecting,
        clearConnectedSince: true,
        clearError: true,
      ),
      VpnError(:final message) => state.copyWith(
        status: VpnStatus.error,
        errorMessage: message,
        clearConnectedSince: true,
      ),
    };
  }

  @override
  Future<void> close() async {
    await _stateSub?.cancel();
    await _trafficSub?.cancel();
    return super.close();
  }
}
