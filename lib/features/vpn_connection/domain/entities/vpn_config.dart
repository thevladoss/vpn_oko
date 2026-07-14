import 'package:equatable/equatable.dart';

class VpnConfig extends Equatable {
  const VpnConfig({
    required this.host,
    required this.port,
    required this.userId,
    required this.serverName,
    required this.singboxConfigJson,
  });

  final String host;
  final int port;
  final String userId;
  final String serverName;
  final String singboxConfigJson;

  @override
  List<Object?> get props => [
        host,
        port,
        userId,
        serverName,
        singboxConfigJson,
      ];
}
