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

  const configA = VpnConfig(
    host: 'a.server',
    port: 443,
    userId: '',
    serverName: 'A',
    singboxConfigJson: '{"outbounds":[{"type":"vless","tag":"a"}]}',
  );

  const configB = VpnConfig(
    host: 'b.server',
    port: 8443,
    userId: '',
    serverName: 'B',
    singboxConfigJson: '{"outbounds":[{"type":"vless","tag":"b"}]}',
  );

  const configC = VpnConfig(
    host: 'c.server',
    port: 2053,
    userId: '',
    serverName: 'C',
    singboxConfigJson: '{"outbounds":[{"type":"vless","tag":"c"}]}',
  );

  final connectedSince = DateTime(2026, 7, 15, 10);

  setUpAll(() {
    registerFallbackValue(configA);
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

  void stubStreams({
    required Stream<VpnState> states,
    Stream<DemoExpiry> demo = const Stream<DemoExpiry>.empty(),
  }) {
    when(() => syncStatus()).thenAnswer((_) async {});
    when(() => watchVpnState()).thenAnswer((_) => states);
    when(() => watchTraffic())
        .thenAnswer((_) => const Stream<TrafficStats>.empty());
    when(() => watchDemoLimit()).thenAnswer((_) => demo);
    when(() => connectVpn(any())).thenAnswer((_) async {});
    when(() => disconnectVpn()).thenAnswer((_) async {});
  }

  Future<VpnConnectionBloc> buildConnected(
    StreamController<VpnState> states, {
    StreamController<DemoExpiry>? demo,
  }) async {
    if (demo == null) {
      stubStreams(states: states.stream);
    } else {
      stubStreams(states: states.stream, demo: demo.stream);
    }
    final bloc = buildBloc()
      ..add(const VpnStarted())
      ..add(const ConfigSelected(configA));
    await pumpEventQueue();
    states.add(VpnConnected(connectedSince: connectedSince));
    await pumpEventQueue();
    return bloc;
  }

  test(
      'different: смена активного сервера в connected рвёт текущий туннель '
      'и поднимает новый после Disconnected', () async {
    final states = StreamController<VpnState>();
    final bloc = await buildConnected(states);
    expect(bloc.state.status, VpnStatus.connected);

    bloc.add(const ConfigSelected(configB));
    await pumpEventQueue();

    verify(() => disconnectVpn()).called(1);
    verifyNever(() => connectVpn(any()));

    states.add(const VpnDisconnected());
    await pumpEventQueue();

    verify(() => connectVpn(configB)).called(1);

    await bloc.close();
    await states.close();
  });

  test(
      'same: повторный выбор того же активного сервера в connected — no-op',
      () async {
    final states = StreamController<VpnState>();
    final bloc = await buildConnected(states);

    bloc.add(const ConfigSelected(configA));
    await pumpEventQueue();

    verifyNever(() => disconnectVpn());
    verifyNever(() => connectVpn(any()));
    expect(bloc.config, configA);

    await bloc.close();
    await states.close();
  });

  blocTest<VpnConnectionBloc, VpnConnectionState>(
    'disconnected: ConfigSelected только запоминает активный конфиг '
    'без reconnect',
    build: buildBloc,
    act: (bloc) => bloc.add(const ConfigSelected(configA)),
    expect: () => const <VpnConnectionState>[],
    verify: (bloc) {
      verifyNever(() => disconnectVpn());
      verifyNever(() => connectVpn(any()));
      expect(bloc.config, configA);
    },
  );

  test(
      'кулдаун-гейт: демо-истечение в окне reconnect блокирует повторный '
      'connect', () async {
    final states = StreamController<VpnState>();
    final demo = StreamController<DemoExpiry>();
    final bloc = await buildConnected(states, demo: demo);

    bloc.add(const ConfigSelected(configB));
    await pumpEventQueue();
    verify(() => disconnectVpn()).called(1);

    demo.add(
      DemoExpiry(
        cooldownUntil: DateTime.now().add(const Duration(minutes: 5)),
        justExpired: true,
      ),
    );
    await pumpEventQueue();

    states.add(const VpnDisconnected());
    await pumpEventQueue();

    verifyNever(() => connectVpn(any()));

    await bloc.close();
    await states.close();
    await demo.close();
  });

  test(
      'latest-wins: серия смен сервера — на Disconnected поднимается '
      'последний выбранный конфиг', () async {
    final states = StreamController<VpnState>();
    final bloc = await buildConnected(states);

    bloc
      ..add(const ConfigSelected(configB))
      ..add(const ConfigSelected(configC));
    await pumpEventQueue();

    verify(() => disconnectVpn()).called(greaterThanOrEqualTo(1));
    expect(bloc.config, configC);

    states.add(const VpnDisconnected());
    await pumpEventQueue();

    verify(() => connectVpn(configC)).called(1);
    verifyNever(() => connectVpn(configB));

    await bloc.close();
    await states.close();
  });
}
