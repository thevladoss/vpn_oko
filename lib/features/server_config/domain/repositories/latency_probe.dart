import 'package:vpn_osin/features/server_config/domain/entities/latency_result.dart';

abstract interface class LatencyProbe {
  Future<LatencyResult> measure(String host, int port);
}
