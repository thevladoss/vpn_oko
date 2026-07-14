import 'package:equatable/equatable.dart';

class VlessConfig extends Equatable {
  const VlessConfig({
    required this.uuid,
    required this.host,
    required this.port,
    required this.transport,
    required this.security,
    required this.name,
    this.sni,
  });

  final String uuid;
  final String host;
  final int port;
  final String transport;
  final String security;
  final String? sni;
  final String name;

  @override
  List<Object?> get props => [uuid, host, port, transport, security, sni, name];
}
