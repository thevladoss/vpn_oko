import 'package:vpn_oko/features/server_config/domain/entities/latency_result.dart';
import 'package:vpn_oko/features/server_config/domain/repositories/latency_probe.dart';

class FakeLatencyProbe implements LatencyProbe {
  FakeLatencyProbe({this.resultToReturn = const LatencyUnreachable()});

  LatencyResult resultToReturn;
  int measureCallCount = 0;
  String? lastHost;
  int? lastPort;

  @override
  Future<LatencyResult> measure(String host, int port) async {
    measureCallCount += 1;
    lastHost = host;
    lastPort = port;
    return resultToReturn;
  }
}
