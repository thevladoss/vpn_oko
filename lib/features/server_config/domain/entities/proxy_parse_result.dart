import 'package:equatable/equatable.dart';
import 'package:vpn_oko/features/server_config/domain/entities/proxy_config.dart';

enum ProxyParseError { empty, unsupported, malformed, missingField }

sealed class ProxyParseResult extends Equatable {
  const ProxyParseResult();

  @override
  List<Object?> get props => const [];
}

final class ProxyParsed extends ProxyParseResult {
  const ProxyParsed(this.config);

  final ProxyConfig config;

  @override
  List<Object?> get props => [config];
}

final class ProxyParseFailure extends ProxyParseResult {
  const ProxyParseFailure(this.error, [this.detail]);

  final ProxyParseError error;
  final String? detail;

  @override
  List<Object?> get props => [error, detail];
}
