import 'package:equatable/equatable.dart';

class VpnConfig extends Equatable {
  const VpnConfig({
    required this.host,
    required this.port,
    required this.userId,
    required this.serverName,
  });

  final String host;
  final int port;
  final String userId;
  final String serverName;

  @override
  List<Object?> get props => [host, port, userId, serverName];
}
