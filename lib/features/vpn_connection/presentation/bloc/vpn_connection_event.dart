import 'package:equatable/equatable.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/demo_limit.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/traffic_stats.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/vpn_config.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/vpn_state.dart';

sealed class VpnConnectionEvent extends Equatable {
  const VpnConnectionEvent();

  @override
  List<Object?> get props => const [];
}

class VpnStarted extends VpnConnectionEvent {
  const VpnStarted();
}

class VpnStateReceived extends VpnConnectionEvent {
  const VpnStateReceived(this.state);

  final VpnState state;

  @override
  List<Object?> get props => [state];
}

class VpnTrafficReceived extends VpnConnectionEvent {
  const VpnTrafficReceived(this.stats);

  final TrafficStats stats;

  @override
  List<Object?> get props => [stats];
}

class ConfigSelected extends VpnConnectionEvent {
  const ConfigSelected(this.config);

  final VpnConfig config;

  @override
  List<Object?> get props => [config];
}

class ConfigCleared extends VpnConnectionEvent {
  const ConfigCleared();
}

class VpnDemoLimitReceived extends VpnConnectionEvent {
  const VpnDemoLimitReceived(this.demo);

  final DemoExpiry demo;

  @override
  List<Object?> get props => [demo];
}

class VpnCooldownElapsed extends VpnConnectionEvent {
  const VpnCooldownElapsed();
}

class ConnectRequested extends VpnConnectionEvent {
  const ConnectRequested();
}

class DisconnectRequested extends VpnConnectionEvent {
  const DisconnectRequested();
}
