import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vpn_osin/core/theme/osin_theme.dart';
import 'package:vpn_osin/core/theme/vpn_status.dart';
import 'package:vpn_osin/core/widgets/top_alert.dart';
import 'package:vpn_osin/features/server_config/domain/entities/proxy_config.dart';
import 'package:vpn_osin/features/server_config/domain/entities/server_profile.dart';
import 'package:vpn_osin/features/server_config/domain/repositories/server_repository.dart';
import 'package:vpn_osin/features/server_config/domain/repositories/settings_repository.dart';
import 'package:vpn_osin/features/server_config/domain/repositories/subscription_repository.dart';
import 'package:vpn_osin/features/server_config/domain/services/singbox_config_builder.dart';
import 'package:vpn_osin/features/server_config/presentation/cubit/auto_switch_cubit.dart';
import 'package:vpn_osin/features/server_config/presentation/cubit/server_list_cubit.dart';
import 'package:vpn_osin/features/server_config/presentation/cubit/subscription_cubit.dart';
import 'package:vpn_osin/features/server_config/presentation/cubit/subscription_state.dart';
import 'package:vpn_osin/features/vpn_connection/data/mappers/proxy_config_mapper.dart';
import 'package:vpn_osin/features/vpn_connection/domain/entities/demo_limit.dart';
import 'package:vpn_osin/features/vpn_connection/domain/entities/traffic_stats.dart';
import 'package:vpn_osin/features/vpn_connection/domain/entities/vpn_config.dart';
import 'package:vpn_osin/features/vpn_connection/domain/entities/vpn_state.dart';
import 'package:vpn_osin/features/vpn_connection/domain/usecases/resolve_active_vpn_config.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/bloc/vpn_connection_bloc.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/bloc/vpn_connection_event.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/screens/vpn_home_screen.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/widgets/auto_switch_toggle.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/widgets/connect_button.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/widgets/cooldown_notice.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/widgets/demo_countdown.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/widgets/demo_expired_overlay.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/widgets/iris_indicator.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/widgets/osin_wordmark.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/widgets/server_card.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/widgets/status_badge.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/widgets/traffic_panel.dart';

import '../../../../helpers/fake_clipboard_source.dart';
import '../../../../helpers/mock_vpn_usecases.dart';
import '../../../../helpers/top_alert_harness.dart';

class MockServerRepository extends Mock implements ServerRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockSubscriptionRepository extends Mock
    implements SubscriptionRepository {}

class MockSubscriptionCubit extends MockCubit<SubscriptionState>
    implements SubscriptionCubit {}

ServerProfile _subServer(int id, String host) => ServerProfile(
  id: id,
  label: host,
  config: VlessConfig(
    uuid: 'deadbeef-1111-2222-3333-444455556666',
    host: host,
    port: 443,
    transport: 'tcp',
    security: 'none',
    name: host,
  ),
  rawUrl: 'vless://x@$host:443',
  createdAt: DateTime(2026, 7, 17),
  subscriptionId: 5,
);

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
  late MockServerRepository repository;
  late FakeClipboardSource clipboard;

  late StreamController<VpnState> stateController;
  late StreamController<TrafficStats> trafficController;
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
    repository = MockServerRepository();
    clipboard = FakeClipboardSource();

    stateController = StreamController<VpnState>.broadcast();
    trafficController = StreamController<TrafficStats>.broadcast();
    demoController = StreamController<DemoExpiry>.broadcast();

    when(() => syncStatus()).thenAnswer((_) async {});
    when(() => watchVpnState()).thenAnswer((_) => stateController.stream);
    when(() => watchTraffic()).thenAnswer((_) => trafficController.stream);
    when(() => watchDemoLimit()).thenAnswer((_) => demoController.stream);
    when(() => connectVpn(any())).thenAnswer((_) async {});
    when(() => disconnectVpn()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await stateController.close();
    await trafficController.close();
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
    bool autoSwitch = false,
    Stream<bool>? autoSwitchStream,
    Future<bool> Function()? autoSwitchEnabled,
    List<ServerProfile> subscriptionServers = const [],
  }) async {
    final serversController = StreamController<List<ServerProfile>>();
    final activeController = StreamController<ServerProfile?>();
    addTearDown(() async {
      await serversController.close();
      await activeController.close();
    });
    when(repository.watchAll).thenAnswer((_) => serversController.stream);
    when(repository.watchActive).thenAnswer((_) => activeController.stream);
    final settings = MockSettingsRepository();
    final subscriptionRepo = MockSubscriptionRepository();
    when(settings.autoSwitchEnabled).thenAnswer(
      (_) async =>
          autoSwitchEnabled != null ? await autoSwitchEnabled() : autoSwitch,
    );
    when(settings.watchAutoSwitch).thenAnswer(
      (_) => autoSwitchStream ?? Stream<bool>.value(autoSwitch),
    );
    when(() => settings.setAutoSwitch(enabled: any(named: 'enabled')))
        .thenAnswer((_) async {});
    when(
      () => subscriptionRepo.serversFor(any()),
    ).thenAnswer((_) async => subscriptionServers);
    final resolveConfig = ResolveActiveVpnConfig(settings, subscriptionRepo);
    final bloc = buildBloc()..add(const VpnStarted());
    final serverList = ServerListCubit(
      repository: repository,
      clipboard: clipboard,
    );
    final autoSwitch$ = AutoSwitchCubit(settings);
    final subscriptions = MockSubscriptionCubit();
    when(() => subscriptions.state).thenReturn(const SubscriptionState());
    addTearDown(() async {
      await bloc.close();
      await serverList.close();
      await autoSwitch$.close();
    });
    final content = MultiBlocProvider(
      providers: [
        BlocProvider<VpnConnectionBloc>.value(value: bloc),
        BlocProvider<ServerListCubit>.value(value: serverList),
        BlocProvider<SubscriptionCubit>.value(value: subscriptions),
        BlocProvider<AutoSwitchCubit>.value(value: autoSwitch$),
      ],
      child: VpnHomeScreen(resolveConfig: resolveConfig),
    );
    await tester.pumpWidget(
      wrapWithTopAlert(
        theme: theme ?? OsinTheme.dark,
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

    expect(find.byType(OsinWordmark), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(find.byType(IrisIndicator), findsOneWidget);
    expect(find.byType(ServerCard), findsOneWidget);
    expect(find.byType(TrafficPanel), findsOneWidget);
    expect(find.byType(ConnectButton), findsOneWidget);
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
    'ON + активный из подписки: Connect шлёт групповой конфиг (urltest)',
    (tester) async {
      useLargeSurface(tester);
      final tokyo = _subServer(1, 'tokyo.example');
      final osaka = _subServer(2, 'osaka.example');

      await pumpScreen(
        tester,
        servers: [tokyo, osaka],
        active: tokyo,
        autoSwitch: true,
        subscriptionServers: [tokyo, osaka],
      );

      await tester.tap(find.byType(ConnectButton));
      await tester.pump();

      final sent =
          verify(() => connectVpn(captureAny())).captured.single as VpnConfig;
      expect(sent.singboxConfigJson, contains('urltest'));
      expect(sent.singboxConfigJson, contains('proxy-0'));
      expect(sent.singboxConfigJson, contains('proxy-1'));
      expect(
        sent.singboxConfigJson,
        toAutoSwitchJson([tokyo.config, osaka.config]),
      );
    },
  );

  testWidgets(
    'OFF + активный из подписки: Connect шлёт одиночный конфиг',
    (tester) async {
      useLargeSurface(tester);
      final tokyo = _subServer(1, 'tokyo.example');
      final osaka = _subServer(2, 'osaka.example');

      await pumpScreen(
        tester,
        servers: [tokyo, osaka],
        active: tokyo,
        subscriptionServers: [tokyo, osaka],
      );

      await tester.tap(find.byType(ConnectButton));
      await tester.pump();

      final sent =
          verify(() => connectVpn(captureAny())).captured.single as VpnConfig;
      expect(sent, proxyConfigToVpnConfig(tokyo.config));
      expect(sent.singboxConfigJson, isNot(contains('urltest')));
    },
  );

  testWidgets('тумблер автопереключения доступен для сервера из подписки', (
    tester,
  ) async {
    useLargeSurface(tester);
    final tokyo = _subServer(1, 'tokyo.example');

    await pumpScreen(
      tester,
      servers: [tokyo],
      active: tokyo,
      subscriptionServers: [tokyo],
    );

    expect(find.byType(AutoSwitchToggle), findsOneWidget);
    final toggle = tester.widget<Switch>(find.byType(Switch));
    expect(toggle.onChanged, isNotNull);
  });

  testWidgets('тумблер автопереключения недоступен для ручного сервера', (
    tester,
  ) async {
    useLargeSurface(tester);

    await pumpScreen(tester, servers: [_tokyo], active: _tokyo);

    expect(find.byType(AutoSwitchToggle), findsOneWidget);
    final toggle = tester.widget<Switch>(find.byType(Switch));
    expect(toggle.onChanged, isNull);
  });

  testWidgets('без активного сервера тумблер не отображается', (tester) async {
    useLargeSurface(tester);

    await pumpScreen(tester);

    expect(find.byType(AutoSwitchToggle), findsNothing);
  });

  testWidgets(
    'переключение тумблера пересобирает активный конфиг (single→group)',
    (tester) async {
      useLargeSurface(tester);
      final tokyo = _subServer(1, 'tokyo.example');
      final osaka = _subServer(2, 'osaka.example');
      final autoController = StreamController<bool>.broadcast();
      addTearDown(autoController.close);
      var enabled = false;

      await pumpScreen(
        tester,
        servers: [tokyo, osaka],
        active: tokyo,
        subscriptionServers: [tokyo, osaka],
        autoSwitchStream: autoController.stream,
        autoSwitchEnabled: () async => enabled,
      );

      enabled = true;
      autoController.add(true);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ConnectButton));
      await tester.pump();

      final sent =
          verify(() => connectVpn(captureAny())).captured.single as VpnConfig;
      expect(sent.singboxConfigJson, contains('urltest'));
      expect(
        sent.singboxConfigJson,
        toAutoSwitchJson([tokyo.config, osaka.config]),
      );
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
    ('dark', OsinTheme.dark),
    ('light', OsinTheme.light),
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
