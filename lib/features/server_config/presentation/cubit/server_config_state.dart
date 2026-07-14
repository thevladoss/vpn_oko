import 'package:equatable/equatable.dart';
import 'package:vpn_oko/features/server_config/domain/entities/latency_result.dart';
import 'package:vpn_oko/features/server_config/domain/entities/proxy_config.dart';
import 'package:vpn_oko/features/server_config/domain/entities/vless_parse_result.dart';

sealed class ServerConfigState extends Equatable {
  const ServerConfigState();

  @override
  List<Object?> get props => const [];
}

class ServerConfigInitial extends ServerConfigState {
  const ServerConfigInitial();
}

class ServerConfigError extends ServerConfigState {
  const ServerConfigError(this.error);

  final VlessError error;

  @override
  List<Object?> get props => [error];
}

class ServerConfigLoaded extends ServerConfigState {
  const ServerConfigLoaded(this.config, {this.latency});

  final VlessConfig config;
  final LatencyResult? latency;

  @override
  List<Object?> get props => [config, latency];
}
