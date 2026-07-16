import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vpn_oko/core/theme/oko_theme.dart';
import 'package:vpn_oko/core/theme/vpn_status.dart';
import 'package:vpn_oko/core/widgets/top_alert.dart';
import 'package:vpn_oko/features/server_config/domain/entities/proxy_config.dart';
import 'package:vpn_oko/features/server_config/domain/entities/server_profile.dart';
import 'package:vpn_oko/features/server_config/domain/repositories/server_repository.dart';
import 'package:vpn_oko/features/server_config/presentation/cubit/server_list_cubit.dart';
import 'package:vpn_oko/features/vpn_connection/data/mappers/proxy_config_mapper.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/demo_limit.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/traffic_stats.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/vpn_config.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/vpn_state.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/bloc/vpn_connection_bloc.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/bloc/vpn_connection_event.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/screens/vpn_home_screen.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/connect_button.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/cooldown_notice.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/demo_countdown.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/demo_expired_overlay.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/iris_indicator.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/oko_wordmark.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/server_card.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/status_badge.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/traffic_panel.dart';
import 'package:vpn_oko/features/vpn_logs/domain/entities/log_entry.dart';
import 'package:vpn_oko/features/vpn_logs/domain/usecases/watch_logs.dart';
import 'package:vpn_oko/features/vpn_logs/presentation/bloc/logs_cubit.dart';
import 'package:vpn_oko/features/vpn_logs/presentation/widgets/log_console.dart';

import '../../../../helpers/fake_clipboard_source.dart';
import '../../../../helpers/mock_vpn_usecases.dart';
import '../../../../helpers/top_alert_harness.dart';

class MockWatchLogs extends Mock implements WatchLogs {}

class MockServerRepository extends Mock implements ServerRepository {}

const _tokyoConfig = VlessConfig(
  uuid: 'deadbeef-1111-2222-3333-444455556666',
  host: 'tokyo.example',
  port: 443,
  transport: 'tcp',
  security: 'reality',
  sni: 'www.microsoft.com',
  name: 'Tokyo',
);

final _tokyo = ServerProfile(
  id: 1,
  label: 'Tokyo',
  config: _tokyoConfig,
  rawUrl: 'vless://deadbeef-1111-2222-3333-444455556666@tokyo.example:443'
      '?type=tcp&security=reality&sni=www.microsoft.com#Tokyo',
  createdAt: DateTime(2026, 7, 14),
);

void main() {
  late MockWatchVpnState watchVpnState;
  late MockWatchTraffic watchTraffic;
  late MockWatchDemoLimit watchDemoLimit;
  late MockConnectVpn connectVpn;
  late MockDisconnectVpn disconnectVpn;
  late MockSyncStatus syncStatus;
  late MockWatchLogs watchLogs;
  late MockServerRepository repository;
  late FakeClipboardSource clipboard;

  late StreamController<VpnState> stateController;
  late StreamController<TrafficStats> trafficController;
  late StreamController<LogEntry> logController;
  late StreamController<DemoExpiry> demoController;

  setUpAll(() {
    registerFallbackValue(
      const VpnConfig(
        host: 'fallback',
        port: 1,
        userId: '',
        serverName: 'fallback',
        singboxConfigJson: '',
      ),
    );
  });

  setUp(() {
    watchVpnState = MockWatchVpnState();
    watchTraffic = MockWatchTraffic();
    watchDemoLimit = MockWatchDemoLimit();
    connectVpn = MockConnectVpn();
    disconnectVpn = MockDisconnectVpn();
    syncStatus = MockSyncStatus();
    watchLogs = MockWatchLogs();
    repository = MockServerRepository();
    clipboard = FakeClipboardSource();

    stateController = StreamController<VpnState>.broadcast();
    trafficController = StreamController<TrafficStats>.broadcast();
    logController = StreamController<LogEntry>.broadcast();
    demoController = StreamController<DemoExpiry>.broadcast();

    when(() => syncStatus()).thenAnswer((_) async {});
    when(() => watchVpnState()).thenAnswer((_) => stateController.stream);
    when(() => watchTraffic()).thenAnswer((_) => trafficController.stream);
    when(() => watchDemoLimit()).thenAnswer((_) => demoController.stream);
    when(() => watchLogs()).thenAnswer((_) => logController.stream);
    when(() => connectVpn(any())).thenAnswer((_) async {});
    when(() => disconnectVpn()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await stateController.close();
    await trafficController.close();
    await logController.close();
    await demoController.close();
  });

  VpnConnectionBloc buildBloc() => VpnConnectionBloc(
    watchVpnState: watchVpnState,
    watchTraffic: watchTraffic,
    watchDemoLimit: watchDemoLimit,
    connectVpn: connectVpn,
    disconnectVpn: disconnectVpn,
    syncStatus: syncStatus,
  );

  Future<VpnConnectionBloc> pumpScreen(
    WidgetTester tester, {
    List<ServerProfile> servers = const [],
    ServerProfile? active,
    ThemeData? theme,
    bool disableAnimations = false,
  }) async {
    final serversController = StreamController<List<ServerProfile>>();
    final activeController = StreamController<ServerProfile?>();
    addTearDown(() async {
      await serversController.close();
      await activeController.close();
    });
    when(repository.watchAll).thenAnswer((_) => serversController.stream);
    when(repository.watchActive).thenAnswer((_) => activeController.stream);
    final bloc = buildBloc()..add(const VpnStarted());
    final logs = LogsCubit(watchLogs: watchLogs);
    final serverList = ServerListCubit(
      repository: repository,
      clipboard: clipboard,
    );
    addTearDown(() async {
      await bloc.close();
      await logs.close();
      await serverList.close();
    });
    final content = MultiBlocProvider(
      providers: [
        BlocProvider<VpnConnectionBloc>.value(value: bloc),
        BlocProvider<LogsCubit>.value(value: logs),
        BlocProvider<ServerListCubit>.value(value: serverList),
      ],
      child: const VpnHomeScreen(),
    );
    await tester.pumpWidget(
      wrapWithTopAlert(
        theme: theme ?? OkoTheme.dark,
        home: disableAnimations
            ? Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    disableAnimations: true,
                  ),
                  child: content,
                ),
              )
            : content,
      ),
    );
    await tester.pump();
    serversController.add(servers);
    activeController.add(active);
    await tester.pumpAndSettle();
    return bloc;
  }

  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('рендерит все зоны экрана с активным сервером', (tester) async {
    useLargeSurface(tester);

    await pumpScreen(tester, servers: [_tokyo], active: _tokyo);

    expect(find.byType(OkoWordmark), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(find.byType(IrisIndicator), findsOneWidget);
    expect(find.byType(ServerCard), findsOneWidget);
    expect(find.byType(TrafficPanel), findsOneWidget);
    expect(find.byType(ConnectButton), findsOneWidget);
    expect(find.byType(LogConsole), findsOneWidget);
    expect(find.text('Tokyo'), findsOneWidget);
  });

  testWidgets(
    'активный сервер driveт Connect: тап шлёт connectVpn с конфигом сервера',
    (tester) async {
      useLargeSurface(tester);

      await pumpScreen(tester, servers: [_tokyo], active: _tokyo);

      final button = tester.widget<ConnectButton>(find.byType(ConnectButton));
      expect(button.onConnect, isNotNull);

      await tester.tap(find.byType(ConnectButton));
      await tester.pump();

      verify(
        () => connectVpn(proxyConfigToVpnConfig(_tokyoConfig)),
      ).called(1);
    },
  );

  testWidgets(
    'нет сервера: тап Connect не поднимает туннель, статус disconnected + '
    'nudge',
    (tester) async {
      useLargeSurface(tester);

      final bloc = await pumpScreen(tester);

      final button = tester.widget<ConnectButton>(find.byType(ConnectButton));
      expect(button.onConnect, isNotNull);
      expect(find.text('Сервер не выбран'), findsOneWidget);
      expect(find.byType(ServerCard), findsNothing);

      await tester.tap(find.byType(ConnectButton));
      await tester.pump();

      verifyNever(() => connectVpn(any()));
      expect(bloc.state.status, VpnStatus.disconnected);
      expect(bloc.state.errorMessage, isNull);
      expect(bloc.state.noServerNudge, greaterThan(0));

      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets('карточка «Сервер не выбран» открывает управление серверами', (
    tester,
  ) async {
    useLargeSurface(tester);

    await pumpScreen(tester);

    await tester.tap(find.text('Сервер не выбран'));
    await tester.pumpAndSettle();

    expect(find.text('Серверы'), findsOneWidget);
  });

  testWidgets(
    'ирис без сервера не поднимает туннель, статус disconnected + nudge',
    (tester) async {
      useLargeSurface(tester);

      final bloc = await pumpScreen(tester);

      await tester.tap(find.byType(IrisIndicator));
      await tester.pump();

      verifyNever(() => connectVpn(any()));
      expect(bloc.state.status, VpnStatus.disconnected);
      expect(bloc.state.errorMessage, isNull);
      expect(bloc.state.noServerNudge, greaterThan(0));

      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets(
    'нет сервера: тап Connect даёт верхний алерт warning без инлайна',
    (tester) async {
      useLargeSurface(tester);

      await pumpScreen(tester);

      expect(find.text(VpnConnectionBloc.noServerHint), findsOneWidget);

      await tester.tap(find.byType(ConnectButton));
      await tester.pumpAndSettle();

      final alert = tester.widget<TopAlert>(find.byType(TopAlert));
      expect(alert.visible, isTrue);
      expect(alert.kind, TopAlertKind.warning);
      expect(alert.message, VpnConnectionBloc.noServerHint);

      expect(find.text(VpnConnectionBloc.noServerHint), findsNWidgets(2));

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('реальная ошибка показывается инлайн под ирисом', (tester) async {
    useLargeSurface(tester);

    await pumpScreen(tester, servers: [_tokyo], active: _tokyo);

    stateController.add(const VpnError('Туннель отклонён устройством'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Туннель отклонён устройством'), findsOneWidget);

    final alert = tester.widget<TopAlert>(find.byType(TopAlert));
    expect(alert.visible, isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('тап по карточке сервера открывает шит', (tester) async {
    useLargeSurface(tester);

    await pumpScreen(tester, servers: [_tokyo], active: _tokyo);

    await tester.tap(find.byType(ServerCard));
    await tester.pumpAndSettle();

    expect(find.text('Серверы'), findsOneWidget);
    expect(find.text('Вставить из буфера'), findsOneWidget);
  });

  testWidgets('ирис в disconnected запускает подключение как Connect', (
    tester,
  ) async {
    useLargeSurface(tester);

    await pumpScreen(tester, servers: [_tokyo], active: _tokyo);

    await tester.tap(find.byType(IrisIndicator));
    await tester.pump();

    verify(() => connectVpn(proxyConfigToVpnConfig(_tokyoConfig))).called(1);
  });

  testWidgets('ирис в connected останавливает VPN', (tester) async {
    useLargeSurface(tester);

    await pumpScreen(tester, servers: [_tokyo], active: _tokyo);

    stateController.add(VpnConnected(connectedSince: DateTime.now()));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byType(IrisIndicator));
    await tester.pump();

    verify(() => disconnectVpn()).called(1);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('ирис в connecting не трогает VPN', (tester) async {
    useLargeSurface(tester);

    await pumpScreen(tester, servers: [_tokyo], active: _tokyo);

    stateController.add(const VpnConnecting());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byType(IrisIndicator), warnIfMissed: false);
    await tester.pump();

    verifyNever(() => connectVpn(any()));
    verifyNever(() => disconnectVpn());

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('connected: показывает обратный отсчёт сессии', (tester) async {
    useLargeSurface(tester);

    await pumpScreen(tester, servers: [_tokyo], active: _tokyo);

    stateController.add(VpnConnected(connectedSince: DateTime.now()));
    await tester.pump();
    await tester.pump();

    expect(find.byType(DemoCountdown), findsOneWidget);
    expect(find.text('Демо'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('demoExpired: показывает оверлей истечения демо', (tester) async {
    useLargeSurface(tester);

    await pumpScreen(tester, servers: [_tokyo], active: _tokyo);

    demoController.add(
      DemoExpiry(
        cooldownUntil: DateTime.now().add(const Duration(milliseconds: 400)),
        justExpired: true,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(DemoExpiredOverlay), findsOneWidget);
    expect(find.text('Вы исчерпали 5 минут демо подключения'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('cooldown без истечения: уведомление и блок Connect', (
    tester,
  ) async {
    useLargeSurface(tester);

    await pumpScreen(tester, servers: [_tokyo], active: _tokyo);

    demoController.add(
      DemoExpiry(
        cooldownUntil: DateTime.now().add(const Duration(milliseconds: 400)),
        justExpired: false,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CooldownNotice), findsOneWidget);
    expect(find.byType(DemoExpiredOverlay), findsNothing);

    final button = tester.widget<ConnectButton>(find.byType(ConnectButton));
    expect(button.onConnect, isNull);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  for (final (name, theme) in <(String, ThemeData)>[
    ('dark', OkoTheme.dark),
    ('light', OkoTheme.light),
  ]) {
    for (final reduceMotion in [false, true]) {
      testWidgets(
        'ирис держит Rect при демо-чипе и кулдауне '
        '($name, reduce=$reduceMotion)',
        (tester) async {
          useLargeSurface(tester);

          await pumpScreen(
            tester,
            servers: [_tokyo],
            active: _tokyo,
            theme: theme,
            disableAnimations: reduceMotion,
          );

          final rectDisconnected = tester.getRect(find.byType(IrisIndicator));

          stateController.add(VpnConnected(connectedSince: DateTime.now()));
          await tester.pump();
          await tester.pump();

          expect(find.byType(DemoCountdown), findsOneWidget);
          expect(
            tester.getRect(find.byType(IrisIndicator)),
            rectDisconnected,
          );

          demoController.add(
            DemoExpiry(
              cooldownUntil: DateTime.now().add(
                const Duration(milliseconds: 400),
              ),
              justExpired: false,
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(find.byType(CooldownNotice), findsOneWidget);
          expect(
            tester.getRect(find.byType(IrisIndicator)),
            rectDisconnected,
          );

          await tester.pump(const Duration(seconds: 1));
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        },
      );
    }
  }
}
