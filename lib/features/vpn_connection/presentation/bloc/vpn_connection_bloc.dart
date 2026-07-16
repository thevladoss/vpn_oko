import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn_oko/core/error/failures.dart';
import 'package:vpn_oko/core/theme/vpn_status.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/demo_limit.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/traffic_stats.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/vpn_config.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/vpn_state.dart';
import 'package:vpn_oko/features/vpn_connection/domain/usecases/connect_vpn.dart';
import 'package:vpn_oko/features/vpn_connection/domain/usecases/disconnect_vpn.dart';
import 'package:vpn_oko/features/vpn_connection/domain/usecases/sync_status.dart';
import 'package:vpn_oko/features/vpn_connection/domain/usecases/watch_demo_limit.dart';
import 'package:vpn_oko/features/vpn_connection/domain/usecases/watch_traffic.dart';
import 'package:vpn_oko/features/vpn_connection/domain/usecases/watch_vpn_state.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/bloc/vpn_connection_event.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/bloc/vpn_connection_state.dart';

class VpnConnectionBloc extends Bloc<VpnConnectionEvent, VpnConnectionState> {
  VpnConnectionBloc({
    required this.watchVpnState,
    required this.watchTraffic,
    required this.watchDemoLimit,
    required this.connectVpn,
    required this.disconnectVpn,
    required this.syncStatus,
  }) : super(const VpnConnectionState(status: VpnStatus.disconnected)) {
    on<VpnStarted>(_onStarted);
    on<VpnStateReceived>(_onStateReceived);
    on<VpnTrafficReceived>(_onTrafficReceived);
    on<VpnDemoLimitReceived>(_onDemoLimitReceived);
    on<VpnCooldownElapsed>(_onCooldownElapsed);
    on<ConfigSelected>(_onConfigSelected);
    on<ConfigCleared>(_onConfigCleared);
    on<ConnectRequested>(_onConnectRequested);
    on<DisconnectRequested>(_onDisconnectRequested);
  }

  static const String noServerHint = 'Выберите сервер, чтобы подключиться';

  final WatchVpnState watchVpnState;
  final WatchTraffic watchTraffic;
  final WatchDemoLimit watchDemoLimit;
  final ConnectVpn connectVpn;
  final DisconnectVpn disconnectVpn;
  final SyncStatus syncStatus;

  VpnConfig? _active;

  VpnConfig? get config => _active;

  VpnConfig? _pendingReconnect;

  StreamSubscription<VpnState>? _stateSub;
  StreamSubscription<TrafficStats>? _trafficSub;
  StreamSubscription<DemoExpiry>? _demoSub;
  Timer? _cooldownTimer;

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
    await _demoSub?.cancel();
    _stateSub = watchVpnState().listen((s) => add(VpnStateReceived(s)));
    _trafficSub = watchTraffic().listen((t) => add(VpnTrafficReceived(t)));
    _demoSub = watchDemoLimit().listen((d) => add(VpnDemoLimitReceived(d)));
  }

  void _onStateReceived(
    VpnStateReceived event,
    Emitter<VpnConnectionState> emit,
  ) {
    emit(_map(event.state));
    final pending = _pendingReconnect;
    if (pending != null && event.state is VpnDisconnected) {
      _pendingReconnect = null;
      if (!state.cooldownActive) unawaited(connectVpn(pending));
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

  void _onDemoLimitReceived(
    VpnDemoLimitReceived event,
    Emitter<VpnConnectionState> emit,
  ) {
    emit(
      state.copyWith(
        status: VpnStatus.disconnected,
        cooldownUntil: event.demo.cooldownUntil,
        demoExpired: event.demo.justExpired,
        clearConnectedSince: true,
        clearSessionEndsAt: true,
      ),
    );
    _armCooldownTimer(event.demo.cooldownUntil);
  }

  void _onCooldownElapsed(
    VpnCooldownElapsed event,
    Emitter<VpnConnectionState> emit,
  ) {
    emit(state.copyWith(clearCooldown: true, demoExpired: false));
  }

  void _armCooldownTimer(DateTime until) {
    _cooldownTimer?.cancel();
    final delay = until.difference(DateTime.now());
    if (delay.isNegative) {
      add(const VpnCooldownElapsed());
      return;
    }
    _cooldownTimer = Timer(delay, () => add(const VpnCooldownElapsed()));
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
    if (state.cooldownActive) return;
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
    if (state.cooldownActive) return;
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
        clearSessionEndsAt: true,
        clearError: true,
      ),
      VpnConnecting() => state.copyWith(
        status: VpnStatus.connecting,
        rxBytes: 0,
        txBytes: 0,
        clearConnectedSince: true,
        clearSessionEndsAt: true,
        clearCooldown: true,
        demoExpired: false,
        clearError: true,
      ),
      VpnConnected(:final connectedSince, :final sessionEndsAt) =>
        state.copyWith(
          status: VpnStatus.connected,
          connectedSince: connectedSince,
          clearConnectedSince: connectedSince == null,
          sessionEndsAt: connectedSince == null
              ? null
              : (sessionEndsAt ?? connectedSince.add(kDemoSessionDuration)),
          clearSessionEndsAt: connectedSince == null,
          clearCooldown: true,
          demoExpired: false,
          clearError: true,
        ),
      VpnDisconnecting() => state.copyWith(
        status: VpnStatus.disconnecting,
        clearConnectedSince: true,
        clearSessionEndsAt: true,
        clearError: true,
      ),
      VpnError(:final message) => state.copyWith(
        status: VpnStatus.error,
        errorMessage: message,
        clearConnectedSince: true,
        clearSessionEndsAt: true,
      ),
    };
  }

  @override
  Future<void> close() async {
    await _stateSub?.cancel();
    await _trafficSub?.cancel();
    await _demoSub?.cancel();
    _cooldownTimer?.cancel();
    return super.close();
  }
}
