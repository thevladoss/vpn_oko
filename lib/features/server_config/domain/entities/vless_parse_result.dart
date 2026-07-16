import 'package:equatable/equatable.dart';
import 'package:vpn_osin/features/server_config/domain/entities/proxy_config.dart';

enum VlessError { empty, malformed, scheme, uuid, host, port }

sealed class VlessParseResult extends Equatable {
  const VlessParseResult();

  @override
  List<Object?> get props => const [];
}

class VlessParsed extends VlessParseResult {
  const VlessParsed(this.config);

  final VlessConfig config;

  @override
  List<Object?> get props => [config];
}

class VlessParseFailure extends VlessParseResult {
  const VlessParseFailure(this.error);

  final VlessError error;

  @override
  List<Object?> get props => [error];
}
