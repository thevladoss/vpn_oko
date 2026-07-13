import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vpn_oko/core/theme/oko_theme.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/traffic_stats.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/vpn_config.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/vpn_state.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/bloc/vpn_connection_bloc.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/bloc/vpn_connection_event.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/screens/vpn_home_screen.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/connect_button.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/iris_indicator.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/oko_wordmark.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/server_card.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/status_badge.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/traffic_panel.dart';
import 'package:vpn_oko/features/vpn_logs/domain/entities/log_entry.dart';
import 'package:vpn_oko/features/vpn_logs/domain/usecases/watch_logs.dart';
import 'package:vpn_oko/features/vpn_logs/presentation/bloc/logs_cubit.dart';
import 'package:vpn_oko/features/vpn_logs/presentation/widgets/log_console.dart';

import '../../../../helpers/mock_vpn_usecases.dart';

class MockWatchLogs extends Mock implements WatchLogs {}

void main() {
  late MockWatchVpnState watchVpnState;
  late MockWatchTraffic watchTraffic;
  late MockConnectVpn connectVpn;
  late MockDisconnectVpn disconnectVpn;
  late MockSyncStatus syncStatus;
  late MockWatchLogs watchLogs;

  late StreamController<VpnState> stateController;
  late StreamController<TrafficStats> trafficController;
  late StreamController<LogEntry> logController;

  const config = VpnConfig(
    host: 'echo.oko.vpn',
    port: 443,
    userId: 'user-1',
    serverName: 'Echo Server',
  );

  setUpAll(() {
    registerFallbackValue(config);
  });

  setUp(() {
    watchVpnState = MockWatchVpnState();
    watchTraffic = MockWatchTraffic();
    connectVpn = MockConnectVpn();
    disconnectVpn = MockDisconnectVpn();
    syncStatus = MockSyncStatus();
    watchLogs = MockWatchLogs();

    stateController = StreamController<VpnState>.broadcast();
    trafficController = StreamController<TrafficStats>.broadcast();
    logController = StreamController<LogEntry>.broadcast();

    when(() => syncStatus()).thenAnswer((_) async {});
    when(() => watchVpnState()).thenAnswer((_) => stateController.stream);
    when(() => watchTraffic()).thenAnswer((_) => trafficController.stream);
    when(() => watchLogs()).thenAnswer((_) => logController.stream);
    when(() => connectVpn(any())).thenAnswer((_) async {});
    when(() => disconnectVpn()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await stateController.close();
    await trafficController.close();
    await logController.close();
  });

  VpnConnectionBloc buildBloc() => VpnConnectionBloc(
        watchVpnState: watchVpnState,
        watchTraffic: watchTraffic,
        connectVpn: connectVpn,
        disconnectVpn: disconnectVpn,
        syncStatus: syncStatus,
        config: config,
      );

  Future<void> pumpScreen(WidgetTester tester) async {
    final bloc = buildBloc()..add(const VpnStarted());
    final cubit = LogsCubit(watchLogs: watchLogs);
    addTearDown(() async {
      await bloc.close();
      await cubit.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: OkoTheme.dark,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<VpnConnectionBloc>.value(value: bloc),
            BlocProvider<LogsCubit>.value(value: cubit),
          ],
          child: const VpnHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('рендерит все зоны экрана поверх реальных Bloc/Cubit',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpScreen(tester);

    expect(find.byType(OkoWordmark), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(find.byType(IrisIndicator), findsOneWidget);
    expect(find.byType(ServerCard), findsOneWidget);
    expect(find.byType(TrafficPanel), findsOneWidget);
    expect(find.byType(ConnectButton), findsOneWidget);
    expect(find.byType(LogConsole), findsOneWidget);
    expect(find.text('Echo Server'), findsOneWidget);
  });

  testWidgets('тап Connect в disconnected шлёт ConnectRequested в Bloc',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpScreen(tester);

    await tester.tap(find.byType(ConnectButton));
    await tester.pump();

    verify(() => connectVpn(config)).called(1);
  });
}
