import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/core/bridge/vpn_api.g.dart';
import 'package:vpn_osin/core/error/failures.dart';
import 'package:vpn_osin/core/error/vpn_exception.dart';
import 'package:vpn_osin/features/vpn_connection/data/repositories/vpn_repository_impl.dart';
import 'package:vpn_osin/features/vpn_connection/domain/entities/demo_limit.dart';
import 'package:vpn_osin/features/vpn_connection/domain/entities/traffic_stats.dart';
import 'package:vpn_osin/features/vpn_connection/domain/entities/vpn_config.dart';
import 'package:vpn_osin/features/vpn_connection/domain/entities/vpn_state.dart';

import '../../../../helpers/fake_vpn_native_datasource.dart';

void main() {
  late FakeVpnNativeDatasource fake;
  late VpnRepositoryImpl repository;

  const demoConfig = VpnConfig(
    host: 'echo.oko.vpn',
    port: 443,
    userId: 'user-1',
    serverName: 'Echo',
    singboxConfigJson: '{"outbounds":[]}',
  );

  setUp(() {
    fake = FakeVpnNativeDatasource();
    repository = VpnRepositoryImpl(fake);
  });

  tearDown(() async {
    await repository.dispose();
    await fake.dispose();
  });

  group('watchState replay', () {
    test('late subscriber receives cached VpnDisconnected first', () async {
      final first = await repository.watchState().first;

      expect(first, const VpnDisconnected());
    });

    test('cache updates from ds.states before a new subscriber listens',
        () async {
      fake.emitState(const VpnConnecting());
      await pumpEventQueue();

      final first = await repository.watchState().first;

      expect(first, const VpnConnecting());
    });

    test('syncStatus reads snapshot and replays it to the next subscriber',
        () async {
      fake.snapshot = VpnStatusSnapshotMessage(
        status: VpnStatusMessage.connected,
        connectedSinceEpochMs: 1000,
        rxBytes: 0,
        txBytes: 0,
      );

      await repository.syncStatus();
      final first = await repository.watchState().first;

      final connectedSince = DateTime.fromMillisecondsSinceEpoch(1000);
      expect(
        first,
        VpnConnected(
          connectedSince: connectedSince,
          sessionEndsAt: connectedSince.add(kDemoSessionDuration),
        ),
      );
    });

    test('does not drop an event emitted right after listen (race window)',
        () async {
      final received = <VpnState>[];
      final subscription = repository.watchState().listen(received.add);

      fake.emitState(const VpnConnecting());
      await pumpEventQueue();
      await subscription.cancel();

      expect(received, <VpnState>[
        const VpnDisconnected(),
        const VpnConnecting(),
      ]);
    });

    test('subscriber before emits receives events in order', () async {
      final received = <VpnState>[];
      final subscription = repository.watchState().listen(received.add);
      await pumpEventQueue();

      fake
        ..emitState(const VpnConnecting())
        ..emitState(
          VpnConnected(connectedSince: DateTime.fromMillisecondsSinceEpoch(0)),
        );
      await pumpEventQueue();
      await subscription.cancel();

      expect(received, <VpnState>[
        const VpnDisconnected(),
        const VpnConnecting(),
        VpnConnected(connectedSince: DateTime.fromMillisecondsSinceEpoch(0)),
      ]);
    });
  });

  group('watchTraffic', () {
    test('proxies datasource traffic stream', () async {
      final received = <TrafficStats>[];
      final subscription = repository.watchTraffic().listen(received.add);
      await pumpEventQueue();

      fake.emitTraffic(const TrafficStats(rxBytes: 5, txBytes: 7));
      await pumpEventQueue();
      await subscription.cancel();

      expect(
        received,
        const <TrafficStats>[TrafficStats(rxBytes: 5, txBytes: 7)],
      );
    });
  });

  group('connect', () {
    test('maps VpnConfig to VpnConfigMessage and forwards to datasource',
        () async {
      await repository.connect(demoConfig);

      final sent = fake.startedWith.single;
      expect(sent.host, demoConfig.host);
      expect(sent.port, demoConfig.port);
      expect(sent.userId, demoConfig.userId);
      expect(sent.serverName, demoConfig.serverName);
      expect(sent.singboxConfigJson, demoConfig.singboxConfigJson);
    });

    test('translates PlatformException into a typed VpnStartFailure', () async {
      fake.startError = PlatformException(
        code: 'consent_denied',
        message: 'User denied VPN consent',
      );

      await expectLater(
        repository.connect(demoConfig),
        throwsA(isA<VpnStartFailure>()),
      );
    });
  });

  group('disconnect', () {
    test('delegates to datasource stop', () async {
      await repository.disconnect();

      expect(fake.stopCount, 1);
    });

    test('translates PlatformException into a typed Failure', () async {
      fake.stopError = PlatformException(
        code: 'stop_failed',
        message: 'Tunnel refused to stop',
      );

      await expectLater(
        repository.disconnect(),
        throwsA(isA<Failure>()),
      );
    });
  });

  group('syncStatus', () {
    test('translates PlatformException into a typed Failure', () async {
      fake.statusError = PlatformException(
        code: 'status_unavailable',
        message: 'getStatus threw',
      );

      await expectLater(
        repository.syncStatus(),
        throwsA(isA<Failure>()),
      );
    });
  });

  group('watchDemoLimit', () {
    test('proxies datasource demo stream', () async {
      final received = <DemoExpiry>[];
      final subscription = repository.watchDemoLimit().listen(received.add);
      await pumpEventQueue();

      final demo = DemoExpiry(
        cooldownUntil: DateTime.fromMillisecondsSinceEpoch(9000),
        justExpired: true,
      );
      fake.emitDemo(demo);
      await pumpEventQueue();
      await subscription.cancel();

      expect(received, <DemoExpiry>[demo]);
    });

    test('syncStatus with cooldown snapshot restores cooldown', () async {
      fake.snapshot = VpnStatusSnapshotMessage(
        status: VpnStatusMessage.disconnected,
        rxBytes: 0,
        txBytes: 0,
        cooldownUntilEpochMs: 12000,
      );
      final received = <DemoExpiry>[];
      final subscription = repository.watchDemoLimit().listen(received.add);
      await pumpEventQueue();

      await repository.syncStatus();
      await pumpEventQueue();
      await subscription.cancel();

      expect(received, <DemoExpiry>[
        DemoExpiry(
          cooldownUntil: DateTime.fromMillisecondsSinceEpoch(12000),
          justExpired: false,
        ),
      ]);
    });

    test('syncStatus without cooldown emits no demo event', () async {
      final received = <DemoExpiry>[];
      final subscription = repository.watchDemoLimit().listen(received.add);
      await pumpEventQueue();

      await repository.syncStatus();
      await pumpEventQueue();
      await subscription.cancel();

      expect(received, isEmpty);
    });
  });

  group('dispose', () {
    test('closes the state stream and is safe to call repeatedly', () async {
      var done = false;
      repository.watchState().listen((_) {}, onDone: () => done = true);
      await pumpEventQueue();

      await repository.dispose();
      await repository.dispose();
      await pumpEventQueue();

      expect(done, isTrue);
    });
  });

  group('mapPlatformException', () {
    test('preserves the platform code in VpnStartFailure', () {
      final failure = mapPlatformException(
        PlatformException(code: 'consent_denied', message: 'denied'),
      );

      expect(failure, isA<VpnStartFailure>());
      expect((failure as VpnStartFailure).code, 'consent_denied');
    });
  });
}
