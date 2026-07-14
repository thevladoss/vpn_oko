import 'package:vpn_oko/features/server_config/domain/entities/latency_result.dart';

abstract interface class LatencyProbe {
  Future<LatencyResult> measure(String host, int port);
}
