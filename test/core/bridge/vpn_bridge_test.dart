import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vpn_osin/core/bridge/vpn_api.g.dart';
import 'package:vpn_osin/core/bridge/vpn_bridge.dart';

import '../../helpers/mock_vpn_host_api.dart';

void main() {
  late StreamController<VpnEventMessage> source;
  late MockVpnHostApi hostApi;
  late VpnBridge bridge;

  setUp(() {
    source = StreamController<VpnEventMessage>();
    hostApi = MockVpnHostApi();
    bridge = VpnBridge(hostApi: hostApi, events: source.stream);
  });

  tearDown(() async {
    await bridge.dispose();
    if (!source.isClosed) {
      await source.close();
    }
  });

  group('demultiplex', () {
    test('routes each event type to its own stream only', () async {
      final statuses = <StatusChangedMessage>[];
      final traffics = <TrafficChangedMessage>[];
      final errors = <ErrorMessage>[];

      bridge.statusEvents.listen(statuses.add);
      bridge.trafficEvents.listen(traffics.add);
      bridge.errorEvents.listen(errors.add);

      final status =
          StatusChangedMessage(status: VpnStatusMessage.connecting);
      final traffic = TrafficChangedMessage(rxBytes: 10, txBytes: 20);
      final error = ErrorMessage(code: 'E1', message: 'boom');

      source
        ..add(status)
        ..add(traffic)
        ..add(error);
      await pumpEventQueue();

      expect(statuses, [status]);
      expect(traffics, [traffic]);
      expect(errors, [error]);
    });

    test('preserves order within a single stream', () async {
      final statuses = <StatusChangedMessage>[];
      bridge.statusEvents.listen(statuses.add);

      final first =
          StatusChangedMessage(status: VpnStatusMessage.connecting);
      final second = StatusChangedMessage(
        status: VpnStatusMessage.connected,
        connectedSinceEpochMs: 5,
      );

      source
        ..add(first)
        ..add(second);
      await pumpEventQueue();

      expect(statuses, [first, second]);
    });

    test('bridge is the single consumer of the source stream', () {
      expect(() => source.stream.listen((_) {}), throwsStateError);
    });
  });

  group('host api proxying', () {
    test('startVpn forwards to hostApi exactly once', () async {
      final config = VpnConfigMessage(
        host: 'h',
        port: 443,
        userId: 'u',
        serverName: 's',
        singboxConfigJson: '',
      );
      when(() => hostApi.startVpn(config)).thenAnswer((_) async {});

      await bridge.startVpn(config);

      verify(() => hostApi.startVpn(config)).called(1);
    });

    test('stopVpn forwards to hostApi exactly once', () async {
      when(() => hostApi.stopVpn()).thenAnswer((_) async {});

      await bridge.stopVpn();

      verify(() => hostApi.stopVpn()).called(1);
    });

    test('getStatus returns the snapshot from hostApi', () async {
      final snapshot = VpnStatusSnapshotMessage(
        status: VpnStatusMessage.connected,
        connectedSinceEpochMs: 5,
        rxBytes: 1,
        txBytes: 2,
      );
      when(() => hostApi.getStatus()).thenAnswer((_) async => snapshot);

      expect(await bridge.getStatus(), snapshot);
      verify(() => hostApi.getStatus()).called(1);
    });
  });
}
