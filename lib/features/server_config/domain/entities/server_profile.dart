import 'package:equatable/equatable.dart';
import 'package:vpn_osin/features/server_config/domain/entities/proxy_config.dart';

class ServerProfile extends Equatable {
  const ServerProfile({
    required this.id,
    required this.label,
    required this.config,
    required this.rawUrl,
    required this.createdAt,
    this.subscriptionId,
  });

  final int id;
  final String label;
  final ProxyConfig config;
  final String rawUrl;
  final DateTime createdAt;
  final int? subscriptionId;

  @override
  List<Object?> get props => [
    id,
    label,
    config,
    rawUrl,
    createdAt,
    subscriptionId,
  ];
}
