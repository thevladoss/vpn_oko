import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn_oko/app/di.dart';
import 'package:vpn_oko/core/theme/oko_theme.dart';
import 'package:vpn_oko/features/server_config/presentation/cubit/server_list_cubit.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/bloc/vpn_connection_bloc.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/bloc/vpn_connection_event.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/screens/vpn_home_screen.dart';
import 'package:vpn_oko/features/vpn_logs/presentation/bloc/logs_cubit.dart';

class OkoApp extends StatelessWidget {
  const OkoApp({
    required this.dependencies,
    this.themeMode = ThemeMode.system,
    super.key,
  });

  final AppDependencies dependencies;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oko VPN',
      theme: OkoTheme.light,
      darkTheme: OkoTheme.dark,
      themeMode: themeMode,
      home: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => VpnConnectionBloc(
              watchVpnState: dependencies.watchVpnState,
              watchTraffic: dependencies.watchTraffic,
              watchDemoLimit: dependencies.watchDemoLimit,
              connectVpn: dependencies.connectVpn,
              disconnectVpn: dependencies.disconnectVpn,
              syncStatus: dependencies.syncStatus,
            )..add(const VpnStarted()),
          ),
          BlocProvider(
            create: (_) => LogsCubit(watchLogs: dependencies.watchLogs),
          ),
          BlocProvider(
            create: (_) => ServerListCubit(
              repository: dependencies.serverRepository,
              clipboard: dependencies.clipboardSource,
            ),
          ),
        ],
        child: const VpnHomeScreen(),
      ),
    );
  }
}
