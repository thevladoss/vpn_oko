import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vpn_oko/core/theme/vpn_status.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/demo_limit.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/traffic_stats.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/vpn_config.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/vpn_state.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/bloc/vpn_connection_bloc.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/bloc/vpn_connection_event.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/bloc/vpn_connection_state.dart';

import '../../../../helpers/mock_vpn_usecases.dart';

void main() {
  late MockWatchVpnState watchVpnState;
  late MockWatchTraffic watchTraffic;
  late MockWatchDemoLimit watchDemoLimit;
  late MockConnectVpn connectVpn;
  late MockDisconnectVpn disconnectVpn;
  late MockSyncStatus syncStatus;

  const selectedConfig = VpnConfig(
    host: 'real.server',
    port: 8443,
    userId: '',
    serverName: 'Real',
    singboxConfigJson: '{"outbounds":[{"type":"vless"}]}',
  );

  const otherConfig = VpnConfig(
    host: 'other.server',
    port: 443,
    userId: '',
    serverName: 'Other',
    singboxConfigJson: '{"outbounds":[{"type":"trojan"}]}',
  );

  final connectedSince = DateTime(2026, 7, 14, 9);

  setUpAll(() {
    registerFallbackValue(selectedConfig);
  });

  setUp(() {
    watchVpnState = MockWatchVpnState();
    watchTraffic = MockWatchTraffic();
    watchDemoLimit = MockWatchDemoLimit();
    connectVpn = MockConnectVpn();
    disconnectVpn = MockDisconnectVpn();
    syncStatus = MockSyncStatus();
  });

  VpnConnectionBloc buildBloc() => VpnConnectionBloc(
        watchVpnState: watchVpnState,
        watchTraffic: watchTraffic,
        watchDemoLimit: watchDemoLimit,
        connectVpn: connectVpn,
        disconnectVpn: disconnectVpn,
        syncStatus: syncStatus,
      );

  void stubStarted({
    required Stream<VpnState> states,
    Stream<TrafficStats> traffic = const Stream<TrafficStats>.empty(),
  }) {
    when(() => syncStatus()).thenAnswer((_) async {});
    when(() => watchVpnState()).thenAnswer((_) => states);
    when(() => watchTraffic()).thenAnswer((_) => traffic);
    when(() => watchDemoLimit())
        .thenAnswer((_) => const Stream<DemoExpiry>.empty());
  }

  blocTest<VpnConnectionBloc, VpnConnectionState>(
    'сценарий 1: disconnected -> connecting -> connected пробрасывает '
    'connectedSince',
    setUp: () => stubStarted(
      states: Stream<VpnState>.fromIterable([
        const VpnConnecting(),
        VpnConnected(connectedSince: connectedSince),
      ]),
    ),
    build: buildBloc,
    act: (bloc) => bloc.add(const VpnStarted()),
    expect: () => [
      isA<VpnConnectionState>()
          .having((s) => s.status, 'status', VpnStatus.connecting),
      isA<VpnConnectionState>()
          .having((s) => s.status, 'status', VpnStatus.connected)
          .having((s) => s.connectedSince, 'connectedSince', connectedSince),
    ],
  );

  blocTest<VpnConnectionBloc, VpnConnectionState>(
    'сценарий 2: DisconnectRequested в connected зовёт disconnectVpn раз, '
    'VpnDisconnected обнуляет connectedSince',
    setUp: () {
      stubStarted(
        states: Stream<VpnState>.fromIterable([const VpnDisconnected()]),
      );
      when(() => disconnectVpn()).thenAnswer((_) async {});
    },
    seed: () => VpnConnectionState(
      status: VpnStatus.connected,
      connectedSince: connectedSince,
    ),
    build: buildBloc,
    act: (bloc) => bloc
      ..add(const DisconnectRequested())
      ..add(const VpnStarted()),
    expect: () => [
      isA<VpnConnectionState>()
          .having((s) => s.status, 'status', VpnStatus.disconnected)
          .having((s) => s.connectedSince, 'connectedSince', isNull),
    ],
    verify: (_) => verify(() => disconnectVpn()).called(1),
  );

  blocTest<VpnConnectionBloc, VpnConnectionState>(
    'сценарий 3: VpnError даёт error+errorMessage, выход из error чистит '
    'errorMessage',
    setUp: () => stubStarted(
      states: Stream<VpnState>.fromIterable([
        const VpnError('boom'),
        const VpnDisconnected(),
      ]),
    ),
    build: buildBloc,
    act: (bloc) => bloc.add(const VpnStarted()),
    expect: () => [
      isA<VpnConnectionState>()
          .having((s) => s.status, 'status', VpnStatus.error)
          .having((s) => s.errorMessage, 'errorMessage', 'boom'),
      isA<VpnConnectionState>()
          .having((s) => s.status, 'status', VpnStatus.disconnected)
          .having((s) => s.errorMessage, 'errorMessage', isNull),
    ],
  );

  blocTest<VpnConnectionBloc, VpnConnectionState>(
    'сценарий 4: onRevoke — VpnDisconnected из стрима не зовёт disconnectVpn',
    setUp: () => stubStarted(
      states: Stream<VpnState>.fromIterable([
        VpnConnected(connectedSince: connectedSince),
        const VpnDisconnected(),
      ]),
    ),
    build: buildBloc,
    act: (bloc) => bloc.add(const VpnStarted()),
    expect: () => [
      isA<VpnConnectionState>()
          .having((s) => s.status, 'status', VpnStatus.connected)
          .having((s) => s.connectedSince, 'connectedSince', connectedSince),
      isA<VpnConnectionState>()
          .having((s) => s.status, 'status', VpnStatus.disconnected)
          .having((s) => s.connectedSince, 'connectedSince', isNull),
    ],
    verify: (_) => verifyNever(() => disconnectVpn()),
  );

  blocTest<VpnConnectionBloc, VpnConnectionState>(
    'сценарий 5a: double-tap — два ConnectRequested в connecting не зовут '
    'connectVpn',
    seed: () => const VpnConnectionState(status: VpnStatus.connecting),
    build: buildBloc,
    act: (bloc) => bloc
      ..add(const ConnectRequested())
      ..add(const ConnectRequested()),
    expect: () => const <VpnConnectionState>[],
    verify: (_) => verifyNever(() => connectVpn(any())),
  );

  blocTest<VpnConnectionBloc, VpnConnectionState>(
    'сценарий 5b: double-tap — два DisconnectRequested в disconnecting не '
    'зовут disconnectVpn',
    seed: () => const VpnConnectionState(status: VpnStatus.disconnecting),
    build: buildBloc,
    act: (bloc) => bloc
      ..add(const DisconnectRequested())
      ..add(const DisconnectRequested()),
    expect: () => const <VpnConnectionState>[],
    verify: (_) => verifyNever(() => disconnectVpn()),
  );

  blocTest<VpnConnectionBloc, VpnConnectionState>(
    'сценарий 6: VpnStarted зовёт syncStatus ровно один раз',
    setUp: () => stubStarted(states: const Stream<VpnState>.empty()),
    build: buildBloc,
    act: (bloc) => bloc.add(const VpnStarted()),
    verify: (_) => verify(() => syncStatus()).called(1),
  );

  blocTest<VpnConnectionBloc, VpnConnectionState>(
    'VpnTrafficReceived обновляет rxBytes и txBytes (стрим трафика жив '
    'параллельно статусу)',
    setUp: () => stubStarted(
      states: const Stream<VpnState>.empty(),
      traffic: Stream<TrafficStats>.fromIterable([
        const TrafficStats(rxBytes: 12, txBytes: 34),
      ]),
    ),
    build: buildBloc,
    act: (bloc) => bloc.add(const VpnStarted()),
    expect: () => [
      isA<VpnConnectionState>()
          .having((s) => s.rxBytes, 'rxBytes', 12)
          .having((s) => s.txBytes, 'txBytes', 34),
    ],
  );

  blocTest<VpnConnectionBloc, VpnConnectionState>(
    'M-01: переход в connecting и disconnected обнуляет rx/tx прошлой сессии',
    setUp: () => stubStarted(
      states: Stream<VpnState>.fromIterable([
        const VpnConnecting(),
        const VpnDisconnected(),
      ]),
    ),
    seed: () => VpnConnectionState(
      status: VpnStatus.connected,
      connectedSince: connectedSince,
      rxBytes: 999,
      txBytes: 888,
    ),
    build: buildBloc,
    act: (bloc) => bloc.add(const VpnStarted()),
    expect: () => [
      isA<VpnConnectionState>()
          .having((s) => s.status, 'status', VpnStatus.connecting)
          .having((s) => s.rxBytes, 'rxBytes', 0)
          .having((s) => s.txBytes, 'txBytes', 0),
      isA<VpnConnectionState>()
          .having((s) => s.status, 'status', VpnStatus.disconnected)
          .having((s) => s.rxBytes, 'rxBytes', 0)
          .having((s) => s.txBytes, 'txBytes', 0),
    ],
  );

  blocTest<VpnConnectionBloc, VpnConnectionState>(
    'гейт: без активного сервера ConnectRequested не зовёт connectVpn, '
    'статус остаётся disconnected и инкрементит noServerNudge',
    build: buildBloc,
    act: (bloc) => bloc.add(const ConnectRequested()),
    expect: () => [
      isA<VpnConnectionState>()
          .having((s) => s.status, 'status', VpnStatus.disconnected)
          .having((s) => s.errorMessage, 'errorMessage', isNull)
          .having((s) => s.noServerNudge, 'noServerNudge', 1),
    ],
    verify: (_) => verifyNever(() => connectVpn(any())),
  );

  blocTest<VpnConnectionBloc, VpnConnectionState>(
    'гейт: два ConnectRequested без сервера подряд дают '
    'noServerNudge 1 затем 2',
    build: buildBloc,
    act: (bloc) => bloc
      ..add(const ConnectRequested())
      ..add(const ConnectRequested()),
    expect: () => [
      isA<VpnConnectionState>()
          .having((s) => s.status, 'status', VpnStatus.disconnected)
          .having((s) => s.noServerNudge, 'noServerNudge', 1),
      isA<VpnConnectionState>()
          .having((s) => s.status, 'status', VpnStatus.disconnected)
          .having((s) => s.noServerNudge, 'noServerNudge', 2),
    ],
    verify: (_) => verifyNever(() => connectVpn(any())),
  );

  blocTest<VpnConnectionBloc, VpnConnectionState>(
    'ConfigSelected делает конфиг активным: ConnectRequested зовёт connectVpn '
    'ровно раз с выбранным конфигом',
    setUp: () => when(() => connectVpn(any())).thenAnswer((_) async {}),
    build: buildBloc,
    act: (bloc) => bloc
      ..add(const ConfigSelected(selectedConfig))
      ..add(const ConnectRequested()),
    verify: (_) {
      verify(() => connectVpn(selectedConfig)).called(1);
      verifyNever(() => connectVpn(otherConfig));
    },
  );

  blocTest<VpnConnectionBloc, VpnConnectionState>(
    'смена активного: последний ConfigSelected побеждает при Connect',
    setUp: () => when(() => connectVpn(any())).thenAnswer((_) async {}),
    build: buildBloc,
    act: (bloc) => bloc
      ..add(const ConfigSelected(otherConfig))
      ..add(const ConfigSelected(selectedConfig))
      ..add(const ConnectRequested()),
    verify: (_) {
      verify(() => connectVpn(selectedConfig)).called(1);
      verifyNever(() => connectVpn(otherConfig));
    },
  );

  blocTest<VpnConnectionBloc, VpnConnectionState>(
    'ConfigCleared сбрасывает активный: следующий ConnectRequested снова '
    'гейтится, не зовёт connectVpn и инкрементит noServerNudge',
    setUp: () => when(() => connectVpn(any())).thenAnswer((_) async {}),
    build: buildBloc,
    act: (bloc) => bloc
      ..add(const ConfigSelected(selectedConfig))
      ..add(const ConfigCleared())
      ..add(const ConnectRequested()),
    expect: () => [
      isA<VpnConnectionState>()
          .having((s) => s.status, 'status', VpnStatus.disconnected)
          .having((s) => s.errorMessage, 'errorMessage', isNull)
          .having((s) => s.noServerNudge, 'noServerNudge', 1),
    ],
    verify: (_) => verifyNever(() => connectVpn(any())),
  );

  blocTest<VpnConnectionBloc, VpnConnectionState>(
    'ConfigSelected в isBusy не роняет Bloc и сохраняет активный конфиг',
    setUp: () => when(() => disconnectVpn()).thenAnswer((_) async {}),
    seed: () => const VpnConnectionState(status: VpnStatus.connecting),
    build: buildBloc,
    act: (bloc) => bloc.add(const ConfigSelected(selectedConfig)),
    expect: () => const <VpnConnectionState>[],
    verify: (bloc) => expect(bloc.config, selectedConfig),
  );

  blocTest<VpnConnectionBloc, VpnConnectionState>(
    'ConfigCleared в isBusy не роняет Bloc и сбрасывает активный конфиг',
    seed: () => const VpnConnectionState(status: VpnStatus.disconnecting),
    build: buildBloc,
    act: (bloc) => bloc
      ..add(const ConfigSelected(selectedConfig))
      ..add(const ConfigCleared()),
    expect: () => const <VpnConnectionState>[],
    verify: (bloc) => expect(bloc.config, isNull),
  );

  test(
      'M-02: повторный VpnStarted не течёт подписками — старые отменяются '
      'перед пересозданием', () async {
    final firstState = StreamController<VpnState>();
    final secondState = StreamController<VpnState>();
    final firstTraffic = StreamController<TrafficStats>();
    final secondTraffic = StreamController<TrafficStats>();
    final stateQueue = [firstState, secondState];
    final trafficQueue = [firstTraffic, secondTraffic];
    when(() => syncStatus()).thenAnswer((_) async {});
    when(() => watchVpnState())
        .thenAnswer((_) => stateQueue.removeAt(0).stream);
    when(() => watchTraffic())
        .thenAnswer((_) => trafficQueue.removeAt(0).stream);
    when(() => watchDemoLimit())
        .thenAnswer((_) => const Stream<DemoExpiry>.empty());

    final bloc = buildBloc()..add(const VpnStarted());
    await pumpEventQueue();

    expect(firstState.hasListener, isTrue);
    expect(firstTraffic.hasListener, isTrue);

    bloc.add(const VpnStarted());
    await pumpEventQueue();

    expect(firstState.hasListener, isFalse);
    expect(firstTraffic.hasListener, isFalse);
    expect(secondState.hasListener, isTrue);
    expect(secondTraffic.hasListener, isTrue);

    await bloc.close();

    expect(secondState.hasListener, isFalse);
    expect(secondTraffic.hasListener, isFalse);

    await firstState.close();
    await secondState.close();
    await firstTraffic.close();
    await secondTraffic.close();
  });

  test('close отменяет подписки на оба стрима', () async {
    final stateController = StreamController<VpnState>();
    final trafficController = StreamController<TrafficStats>();
    when(() => syncStatus()).thenAnswer((_) async {});
    when(() => watchVpnState()).thenAnswer((_) => stateController.stream);
    when(() => watchTraffic()).thenAnswer((_) => trafficController.stream);
    when(() => watchDemoLimit())
        .thenAnswer((_) => const Stream<DemoExpiry>.empty());

    final bloc = buildBloc()..add(const VpnStarted());
    await pumpEventQueue();

    expect(stateController.hasListener, isTrue);
    expect(trafficController.hasListener, isTrue);

    await bloc.close();

    expect(stateController.hasListener, isFalse);
    expect(trafficController.hasListener, isFalse);

    await stateController.close();
    await trafficController.close();
  });
}
