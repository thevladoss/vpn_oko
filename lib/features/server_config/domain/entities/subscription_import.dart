import 'package:equatable/equatable.dart';
import 'package:vpn_osin/features/server_config/domain/entities/proxy_config.dart';

enum SubscriptionFormat {
  base64List,
  uriList,
  singboxJson,
  clashYaml,
  unknown,
}

class ImportedProxy extends Equatable {
  const ImportedProxy({required this.config, required this.rawUrl});

  final ProxyConfig config;
  final String rawUrl;

  @override
  List<Object?> get props => [config, rawUrl];
}

class SubscriptionImport extends Equatable {
  const SubscriptionImport({
    required this.servers,
    required this.skipped,
    required this.format,
  });

  final List<ImportedProxy> servers;
  final int skipped;
  final SubscriptionFormat format;

  @override
  List<Object?> get props => [servers, skipped, format];
}
