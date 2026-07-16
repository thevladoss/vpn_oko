import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn_oko/app/di.dart';
import 'package:vpn_oko/core/theme/oko_theme.dart';
import 'package:vpn_oko/core/widgets/top_alert_controller.dart';
import 'package:vpn_oko/core/widgets/top_alert_overlay.dart';
import 'package:vpn_oko/core/widgets/top_alert_scope.dart';
import 'package:vpn_oko/features/server_config/presentation/cubit/server_list_cubit.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/bloc/vpn_connection_bloc.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/bloc/vpn_connection_event.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/screens/vpn_home_screen.dart';
import 'package:vpn_oko/features/vpn_logs/presentation/bloc/logs_cubit.dart';

class OkoApp extends StatefulWidget {
  const OkoApp({
    required this.dependencies,
    this.themeMode = ThemeMode.system,
    super.key,
  });

  final AppDependencies dependencies;
  final ThemeMode themeMode;

  @override
  State<OkoApp> createState() => _OkoAppState();
}

class _OkoAppState extends State<OkoApp> {
  final TopAlertController _alerts = TopAlertController();

  @override
  void dispose() {
    _alerts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TopAlertScope(
      controller: _alerts,
      child: MaterialApp(
        title: 'Oko VPN',
        theme: OkoTheme.light,
        darkTheme: OkoTheme.dark,
        themeMode: widget.themeMode,
        builder: (context, child) => Stack(
          children: [
            ?child,
            TopAlertOverlay(controller: _alerts),
          ],
        ),
        home: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => VpnConnectionBloc(
                watchVpnState: widget.dependencies.watchVpnState,
                watchTraffic: widget.dependencies.watchTraffic,
                watchDemoLimit: widget.dependencies.watchDemoLimit,
                connectVpn: widget.dependencies.connectVpn,
                disconnectVpn: widget.dependencies.disconnectVpn,
                syncStatus: widget.dependencies.syncStatus,
              )..add(const VpnStarted()),
            ),
            BlocProvider(
              create: (_) =>
                  LogsCubit(watchLogs: widget.dependencies.watchLogs),
            ),
            BlocProvider(
              create: (_) => ServerListCubit(
                repository: widget.dependencies.serverRepository,
                clipboard: widget.dependencies.clipboardSource,
              ),
            ),
          ],
          child: const VpnHomeScreen(),
        ),
      ),
    );
  }
}
