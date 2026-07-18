import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn_osin/core/error/failures.dart';
import 'package:vpn_osin/core/theme/vpn_status.dart';
import 'package:vpn_osin/features/vpn_connection/domain/entities/traffic_stats.dart';
import 'package:vpn_osin/features/vpn_connection/domain/entities/vpn_config.dart';
import 'package:vpn_osin/features/vpn_connection/domain/entities/vpn_state.dart';
import 'package:vpn_osin/features/vpn_connection/domain/usecases/connect_vpn.dart';
import 'package:vpn_osin/features/vpn_connection/domain/usecases/disconnect_vpn.dart';
import 'package:vpn_osin/features/vpn_connection/domain/usecases/sync_status.dart';
import 'package:vpn_osin/features/vpn_connection/domain/usecases/watch_traffic.dart';
import 'package:vpn_osin/features/vpn_connection/domain/usecases/watch_vpn_state.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/bloc/vpn_connection_event.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/bloc/vpn_connection_state.dart';

class VpnConnectionBloc extends Bloc<VpnConnectionEvent, VpnConnectionState> {
  VpnConnectionBloc({
    required this.watchVpnState,
    required this.watchTraffic,
    required this.connectVpn,
    required this.disconnectVpn,
    required this.syncStatus,
  }) : super(const VpnConnectionState(status: VpnStatus.disconnected)) {
    on<VpnStarted>(_onStarted);
    on<VpnStateReceived>(_onStateReceived);
    on<VpnTrafficReceived>(_onTrafficReceived);
    on<ConfigSelected>(_onConfigSelected);
    on<ConfigCleared>(_onConfigCleared);
    on<ConnectRequested>(_onConnectRequested);
    on<DisconnectRequested>(_onDisconnectRequested);
  }

  static const String noServerHint = 'Выберите сервер, чтобы подключиться';

  final WatchVpnState watchVpnState;
  final WatchTraffic watchTraffic;
  final ConnectVpn connectVpn;
  final DisconnectVpn disconnectVpn;
  final SyncStatus syncStatus;

  VpnConfig? _active;

  VpnConfig? get config => _active;

  VpnConfig? _pendingReconnect;

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
            SubscriptionFailure(:final message) => message,
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
    final pending = _pendingReconnect;
    if (pending != null && event.state is VpnDisconnected) {
      _pendingReconnect = null;
      unawaited(connectVpn(pending));
    }
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
    final previous = _active;
    _active = event.config;
    if (previous == event.config) return;
    final status = state.status;
    if (status != VpnStatus.connecting && status != VpnStatus.connected) {
      return;
    }
    _pendingReconnect = event.config;
    unawaited(disconnectVpn());
  }

  void _onConfigCleared(
    ConfigCleared event,
    Emitter<VpnConnectionState> emit,
  ) {
    _active = null;
  }

  void _onConnectRequested(
    ConnectRequested event,
    Emitter<VpnConnectionState> emit,
  ) {
    if (state.isBusy) return;
    final active = _active;
    if (active == null) {
      emit(state.copyWith(noServerNudge: state.noServerNudge + 1));
      return;
    }
    unawaited(connectVpn(active));
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
