import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_oko/features/server_config/data/probes/socket_latency_probe.dart';
import 'package:vpn_oko/features/server_config/domain/entities/latency_result.dart';
import 'package:vpn_oko/features/server_config/domain/repositories/latency_probe.dart';

void main() {
  test('measure returns LatencyMeasured for a reachable host', () async {
    Future<void> connect(String host, int port, Duration timeout) =>
        Future<void>.delayed(const Duration(milliseconds: 2));
    final probe = SocketLatencyProbe(connector: connect);

    final result = await probe.measure('example.com', 443);

    expect(result, isA<LatencyMeasured>());
    final measured = result as LatencyMeasured;
    expect(measured.rtt.inMilliseconds, greaterThanOrEqualTo(0));
  });

  test('measure returns LatencyUnreachable when the connector throws',
      () async {
    Future<void> connect(String host, int port, Duration timeout) =>
        Future<void>.error(const SocketException('refused'));
    final probe = SocketLatencyProbe(connector: connect);

    final result = await probe.measure('10.0.0.1', 9999);

    expect(result, const LatencyUnreachable());
  });

  test('measure returns LatencyUnreachable on a non-SocketException timeout',
      () async {
    Future<void> connect(String host, int port, Duration timeout) =>
        Future<void>.error(TimeoutException('slow'));
    final probe = SocketLatencyProbe(connector: connect);

    final result = await probe.measure('10.0.0.1', 9999);

    expect(result, const LatencyUnreachable());
  });

  test('measure returns LatencyUnreachable when the connector throws an Error',
      () async {
    Future<void> connect(String host, int port, Duration timeout) =>
        Future<void>.error(StateError('boom'));
    final probe = SocketLatencyProbe(connector: connect);

    final result = await probe.measure('h', 1);

    expect(result, const LatencyUnreachable());
  });

  test('measure forwards host, port and timeout to the connector', () async {
    String? capturedHost;
    int? capturedPort;
    Duration? capturedTimeout;
    Future<void> connect(String host, int port, Duration timeout) async {
      capturedHost = host;
      capturedPort = port;
      capturedTimeout = timeout;
    }

    const timeout = Duration(milliseconds: 500);
    final probe = SocketLatencyProbe(connector: connect, timeout: timeout);

    await probe.measure('vpn.example', 8443);

    expect(capturedHost, 'vpn.example');
    expect(capturedPort, 8443);
    expect(capturedTimeout, timeout);
  });

  test('exposes a valid const constructor for dependency injection', () {
    const probe = SocketLatencyProbe();

    expect(probe, isA<LatencyProbe>());
  });
}
