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

  const config = VpnConfig(
    host: 'echo.oko.vpn',
    port: 443,
    userId: 'user-1',
    serverName: 'Echo',
    singboxConfigJson: '',
  );

  final connectedSince = DateTime(2026, 7, 14, 9);
  final cooldownUntil = DateTime.now().add(const Duration(minutes: 2));

  setUpAll(() {
    registerFallbackValue(config);
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
    Stream<VpnState> states = const Stream<VpnState>.empty(),
    Stream<TrafficStats> traffic = const Stream<TrafficStats>.empty(),
    Stream<DemoExpiry> demo = const Stream<DemoExpiry>.empty(),
  }) {
    when(() => syncStatus()).thenAnswer((_) async {});
    when(() => watchVpnState()).thenAnswer((_) => states);
    when(() => watchTraffic()).thenAnswer((_) => traffic);
    when(() => watchDemoLimit()).thenAnswer((_) => demo);
  }

  blocTest<VpnConnectionBloc, VpnConnectionState>(
    'истечение: DemoExpiry(justExpired:true) даёт demoExpired и cooldownUntil, '
    'статус остаётся disconnected',
    setUp: () => stubStarted(
      demo: Stream<DemoExpiry>.fromIterable([
        DemoExpiry(cooldownUntil: cooldownUntil, justExpired: true),
      ]),
    ),
    build: buildBloc,
    act: (bloc) => bloc.add(const VpnStarted()),
    expect: () => [
      isA<VpnConnectionState>()
          .having((s) => s.status, 'status', VpnStatus.disconnected)
          .having((s) => s.demoExpired, 'demoExpired', true)
          .having((s) => s.cooldownUntil, 'cooldownUntil', cooldownUntil),
    ],
  );

  blocTest<VpnConnectionBloc, VpnConnectionState>(
    'восстановление кулдауна: DemoExpiry(justExpired:false) даёт '
    'demoExpired==false с выставленным cooldownUntil',
    setUp: () => stubStarted(
      demo: Stream<DemoExpiry>.fromIterable([
        DemoExpiry(cooldownUntil: cooldownUntil, justExpired: false),
      ]),
    ),
    build: buildBloc,
    act: (bloc) => bloc.add(const VpnStarted()),
    expect: () => [
      isA<VpnConnectionState>()
          .having((s) => s.demoExpired, 'demoExpired', false)
          .having((s) => s.cooldownUntil, 'cooldownUntil', cooldownUntil),
    ],
  );

  blocTest<VpnConnectionBloc, VpnConnectionState>(
    'connected без sessionEndsAt деривирует его из connectedSince',
    setUp: () => stubStarted(
      states: Stream<VpnState>.fromIterable([
        VpnConnected(connectedSince: connectedSince),
      ]),
    ),
    build: buildBloc,
    act: (bloc) => bloc.add(const VpnStarted()),
    expect: () => [
      isA<VpnConnectionState>()
          .having((s) => s.status, 'status', VpnStatus.connected)
          .having(
            (s) => s.sessionEndsAt,
            'sessionEndsAt',
            connectedSince.add(kDemoSessionDuration),
          ),
    ],
  );

  blocTest<VpnConnectionBloc, VpnConnectionState>(
    'connected c sessionEndsAt из снапшота берёт именно его',
    setUp: () {
      final sessionEndsAt = connectedSince.add(const Duration(minutes: 3));
      stubStarted(
        states: Stream<VpnState>.fromIterable([
          VpnConnected(
            connectedSince: connectedSince,
            sessionEndsAt: sessionEndsAt,
          ),
        ]),
      );
    },
    build: buildBloc,
    act: (bloc) => bloc.add(const VpnStarted()),
    expect: () => [
      isA<VpnConnectionState>()
          .having((s) => s.status, 'status', VpnStatus.connected)
          .having(
            (s) => s.sessionEndsAt,
            'sessionEndsAt',
            connectedSince.add(const Duration(minutes: 3)),
          ),
    ],
  );

  blocTest<VpnConnectionBloc, VpnConnectionState>(
    'гейт кулдауна: ConnectRequested в активном кулдауне не зовёт connectVpn',
    seed: () => VpnConnectionState(
      status: VpnStatus.disconnected,
      cooldownUntil: cooldownUntil,
      demoExpired: true,
    ),
    build: buildBloc,
    act: (bloc) => bloc.add(const ConnectRequested()),
    expect: () => const <VpnConnectionState>[],
    verify: (_) => verifyNever(() => connectVpn(any())),
  );

  blocTest<VpnConnectionBloc, VpnConnectionState>(
    'порядко-независимость: DemoExpiry затем VpnDisconnected — итог сохраняет '
    'cooldownUntil и demoExpired (Disconnected их не чистит)',
    seed: () => VpnConnectionState(
      status: VpnStatus.connected,
      connectedSince: connectedSince,
    ),
    build: buildBloc,
    act: (bloc) => bloc
      ..add(
        VpnDemoLimitReceived(
          DemoExpiry(cooldownUntil: cooldownUntil, justExpired: true),
        ),
      )
      ..add(const VpnStateReceived(VpnDisconnected())),
    expect: () => [
      isA<VpnConnectionState>()
          .having((s) => s.status, 'status', VpnStatus.disconnected)
          .having((s) => s.demoExpired, 'demoExpired', true)
          .having((s) => s.cooldownUntil, 'cooldownUntil', cooldownUntil),
    ],
  );

  blocTest<VpnConnectionBloc, VpnConnectionState>(
    'порядко-независимость: VpnDisconnected затем DemoExpiry — демо-поля '
    'ложатся поверх disconnected',
    seed: () => VpnConnectionState(
      status: VpnStatus.connected,
      connectedSince: connectedSince,
    ),
    build: buildBloc,
    act: (bloc) => bloc
      ..add(const VpnStateReceived(VpnDisconnected()))
      ..add(
        VpnDemoLimitReceived(
          DemoExpiry(cooldownUntil: cooldownUntil, justExpired: true),
        ),
      ),
    expect: () => [
      isA<VpnConnectionState>()
          .having((s) => s.status, 'status', VpnStatus.disconnected)
          .having((s) => s.demoExpired, 'demoExpired', false)
          .having((s) => s.cooldownUntil, 'cooldownUntil', isNull),
      isA<VpnConnectionState>()
          .having((s) => s.status, 'status', VpnStatus.disconnected)
          .having((s) => s.demoExpired, 'demoExpired', true)
          .having((s) => s.cooldownUntil, 'cooldownUntil', cooldownUntil),
    ],
  );

  blocTest<VpnConnectionBloc, VpnConnectionState>(
    'reconnect после кулдауна: VpnCooldownElapsed чистит кулдаун, следующий '
    'ConnectRequested зовёт connectVpn на активном сервере',
    setUp: () => when(() => connectVpn(any())).thenAnswer((_) async {}),
    seed: () => VpnConnectionState(
      status: VpnStatus.disconnected,
      cooldownUntil: cooldownUntil,
      demoExpired: true,
    ),
    build: buildBloc,
    act: (bloc) => bloc
      ..add(const ConfigSelected(config))
      ..add(const VpnCooldownElapsed())
      ..add(const ConnectRequested()),
    expect: () => [
      isA<VpnConnectionState>()
          .having((s) => s.demoExpired, 'demoExpired', false)
          .having((s) => s.cooldownUntil, 'cooldownUntil', isNull),
    ],
    verify: (_) => verify(() => connectVpn(config)).called(1),
  );

  blocTest<VpnConnectionBloc, VpnConnectionState>(
    'новая сессия: VpnConnecting чистит cooldownUntil/demoExpired/sessionEndsAt',
    seed: () => VpnConnectionState(
      status: VpnStatus.disconnected,
      cooldownUntil: cooldownUntil,
      demoExpired: true,
      sessionEndsAt: connectedSince,
    ),
    build: buildBloc,
    act: (bloc) => bloc.add(const VpnStateReceived(VpnConnecting())),
    expect: () => [
      isA<VpnConnectionState>()
          .having((s) => s.status, 'status', VpnStatus.connecting)
          .having((s) => s.cooldownUntil, 'cooldownUntil', isNull)
          .having((s) => s.demoExpired, 'demoExpired', false)
          .having((s) => s.sessionEndsAt, 'sessionEndsAt', isNull),
    ],
  );
}
