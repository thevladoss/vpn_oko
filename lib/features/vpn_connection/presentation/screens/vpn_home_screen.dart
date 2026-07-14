import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn_oko/core/theme/oko_motion.dart';
import 'package:vpn_oko/core/theme/oko_tones.dart';
import 'package:vpn_oko/core/theme/vpn_status.dart';
import 'package:vpn_oko/features/server_config/presentation/cubit/server_config_cubit.dart';
import 'package:vpn_oko/features/server_config/presentation/cubit/server_config_state.dart';
import 'package:vpn_oko/features/server_config/presentation/widgets/paste_config_button.dart';
import 'package:vpn_oko/features/server_config/presentation/widgets/vless_config_card.dart';
import 'package:vpn_oko/features/server_config/presentation/widgets/vless_error_text.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/bloc/vpn_connection_bloc.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/bloc/vpn_connection_event.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/bloc/vpn_connection_state.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/connect_button.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/iris_indicator.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/oko_wordmark.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/server_card.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/status_badge.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/traffic_panel.dart';
import 'package:vpn_oko/features/vpn_logs/presentation/widgets/log_console.dart';

class VpnHomeScreen extends StatefulWidget {
  const VpnHomeScreen({super.key});

  @override
  State<VpnHomeScreen> createState() => _VpnHomeScreenState();
}

class _VpnHomeScreenState extends State<VpnHomeScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _total = Duration(milliseconds: 590);

  late final AnimationController _entrance;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: _total);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      unawaited(_entrance.forward());
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Interval _interval(Duration start) {
    final begin = start.inMilliseconds / _total.inMilliseconds;
    final end =
        (start.inMilliseconds + OkoMotion.enterScreen.inMilliseconds) /
        _total.inMilliseconds;
    return Interval(begin, end, curve: OkoMotion.enterScreenCurve);
  }

  void _pasteConfig(BuildContext context) {
    unawaited(HapticFeedback.mediumImpact());
    unawaited(context.read<ServerConfigCubit>().pasteFromClipboard());
  }

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    final textTheme = Theme.of(context).textTheme;
    final config = context.read<VpnConnectionBloc>().config;
    final sheetPeek = MediaQuery.sizeOf(context).height * 0.12;
    return Scaffold(
      body: BlocBuilder<VpnConnectionBloc, VpnConnectionState>(
        builder: (context, state) {
          final accent = tones.accentFor(state.status);
          return Stack(
            children: [
              _GlowLayer(accent: accent, status: state.status),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 56,
                        child: Row(
                          children: [
                            OkoWordmark(status: state.status),
                            const Spacer(),
                            StatusBadge(status: state.status),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _Staggered(
                          animation: _entrance,
                          interval: _interval(OkoMotion.staggerIris),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: IrisIndicator(
                              status: state.status,
                              connectedSince: state.connectedSince,
                            ),
                          ),
                        ),
                      ),
                      if (state.status == VpnStatus.error &&
                          state.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            state.errorMessage!,
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall?.copyWith(
                              color: tones.accentError,
                            ),
                          ),
                        ),
                      _Staggered(
                        animation: _entrance,
                        interval: _interval(OkoMotion.staggerServerCard),
                        child: Column(
                          children: [
                            BlocBuilder<ServerConfigCubit, ServerConfigState>(
                              builder: (context, cfgState) =>
                                  switch (cfgState) {
                                    ServerConfigLoaded(
                                      :final config,
                                      :final latency,
                                    ) =>
                                      VlessConfigCard(
                                        config: config,
                                        latency: latency,
                                      ),
                                    ServerConfigError(:final error) => Column(
                                      children: [
                                        ServerCard(
                                          serverName: config.serverName,
                                          host: config.host,
                                          port: config.port,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          describeVlessError(error),
                                          textAlign: TextAlign.center,
                                          style: textTheme.bodySmall?.copyWith(
                                            color: tones.accentError,
                                          ),
                                        ),
                                      ],
                                    ),
                                    ServerConfigInitial() => ServerCard(
                                      serverName: config.serverName,
                                      host: config.host,
                                      port: config.port,
                                    ),
                                  },
                            ),
                            const SizedBox(height: 12),
                            PasteConfigButton(
                              onPressed: () => _pasteConfig(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _Staggered(
                        animation: _entrance,
                        interval: _interval(OkoMotion.staggerTrafficPanel),
                        child: TrafficPanel(
                          rxBytes: state.rxBytes,
                          txBytes: state.txBytes,
                          status: state.status,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _Staggered(
                        animation: _entrance,
                        interval: _interval(OkoMotion.staggerConnectButton),
                        child: ConnectButton(
                          status: state.status,
                          onConnect: () => context
                              .read<VpnConnectionBloc>()
                              .add(const ConnectRequested()),
                          onDisconnect: () => context
                              .read<VpnConnectionBloc>()
                              .add(const DisconnectRequested()),
                        ),
                      ),
                      SizedBox(height: sheetPeek),
                    ],
                  ),
                ),
              ),
              _Staggered(
                animation: _entrance,
                interval: _interval(OkoMotion.staggerLogConsole),
                child: const LogConsole(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GlowLayer extends StatelessWidget {
  const _GlowLayer({required this.accent, required this.status});

  final Color accent;
  final VpnStatus status;

  @override
  Widget build(BuildContext context) {
    final intensity = status == VpnStatus.disconnected ? 0.0 : 0.16;
    return Positioned.fill(
      child: AnimatedContainer(
        duration: OkoMotion.statusCrossfade,
        curve: OkoMotion.statusCrossfadeCurve,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.35),
            radius: 0.9,
            colors: [
              accent.withValues(alpha: intensity),
              accent.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _Staggered extends StatelessWidget {
  const _Staggered({
    required this.animation,
    required this.interval,
    required this.child,
  });

  final Animation<double> animation;
  final Interval interval;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = interval.transform(animation.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 24),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
