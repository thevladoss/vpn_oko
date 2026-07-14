import 'dart:io';

import 'package:vpn_oko/features/server_config/domain/entities/latency_result.dart';
import 'package:vpn_oko/features/server_config/domain/repositories/latency_probe.dart';

typedef TcpConnector = Future<void> Function(
  String host,
  int port,
  Duration timeout,
);

class SocketLatencyProbe implements LatencyProbe {
  const SocketLatencyProbe({
    this.connector,
    this.timeout = const Duration(seconds: 3),
  });

  final TcpConnector? connector;
  final Duration timeout;

  @override
  Future<LatencyResult> measure(String host, int port) async {
    final connect = connector ?? _defaultConnect;
    final sw = Stopwatch()..start();
    try {
      await connect(host, port, timeout);
      sw.stop();
      return LatencyMeasured(Duration(milliseconds: sw.elapsedMilliseconds));
    } on SocketException {
      return const LatencyUnreachable();
    }
  }

  Future<void> _defaultConnect(String host, int port, Duration timeout) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    socket.destroy();
  }
}
