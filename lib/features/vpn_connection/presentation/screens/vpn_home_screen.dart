import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn_oko/core/theme/oko_motion.dart';
import 'package:vpn_oko/core/theme/oko_tones.dart';
import 'package:vpn_oko/core/theme/vpn_status.dart';
import 'package:vpn_oko/features/server_config/domain/entities/server_profile.dart';
import 'package:vpn_oko/features/server_config/presentation/cubit/server_list_cubit.dart';
import 'package:vpn_oko/features/server_config/presentation/cubit/server_list_state.dart';
import 'package:vpn_oko/features/server_config/presentation/screens/server_management_sheet.dart';
import 'package:vpn_oko/features/vpn_connection/data/mappers/proxy_config_mapper.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/bloc/vpn_connection_bloc.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/bloc/vpn_connection_event.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/bloc/vpn_connection_state.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/connect_button.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/cooldown_notice.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/demo_countdown.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/demo_expired_overlay.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/iris_indicator.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/oko_wordmark.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/server_card.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/status_badge.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/traffic_panel.dart';
import 'package:vpn_oko/features/vpn_logs/presentation/widgets/log_console.dart';

ServerProfile? activeServerProfile(ServerListState state) {
  final id = state.activeId;
  if (id == null) {
    return null;
  }
  for (final profile in state.servers) {
    if (profile.id == id) {
      return profile;
    }
  }
  return null;
}

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

  void _openServerSheet(BuildContext context) {
    final cubit = context.read<ServerListCubit>();
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: const ServerManagementSheet(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    final textTheme = Theme.of(context).textTheme;
    return BlocListener<ServerListCubit, ServerListState>(
      listenWhen: (previous, current) {
        final before = activeServerProfile(previous);
        final after = activeServerProfile(current);
        return before?.id != after?.id || before?.config != after?.config;
      },
      listener: (context, serverState) {
        final active = activeServerProfile(serverState);
        final bloc = context.read<VpnConnectionBloc>();
        if (active == null) {
          bloc.add(const ConfigCleared());
        } else {
          bloc.add(ConfigSelected(proxyConfigToVpnConfig(active.config)));
        }
      },
      child: Scaffold(
        body: BlocBuilder<VpnConnectionBloc, VpnConnectionState>(
          builder: (context, state) {
            final accent = tones.accentFor(state.status);
            final activeProfile = activeServerProfile(
              context.watch<ServerListCubit>().state,
            );
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
                        if (state.status == VpnStatus.connected &&
                            state.sessionEndsAt != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _DemoSessionChip(
                              deadline: state.sessionEndsAt!,
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
                              if (activeProfile != null)
                                ServerCard(
                                  serverName: activeProfile.label,
                                  host: activeProfile.config.host,
                                  port: activeProfile.config.port,
                                )
                              else
                                _NoServerCard(
                                  tones: tones,
                                  textTheme: textTheme,
                                ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () => _openServerSheet(context),
                                icon: const Icon(Icons.dns_rounded),
                                label: const Text('Управление серверами'),
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
                        if (state.cooldownActive &&
                            !state.demoExpired &&
                            state.cooldownUntil != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: CooldownNotice(
                              cooldownUntil: state.cooldownUntil!,
                            ),
                          ),
                        _Staggered(
                          animation: _entrance,
                          interval: _interval(OkoMotion.staggerConnectButton),
                          child: ConnectButton(
                            status: state.status,
                            onConnect: state.cooldownActive ||
                                    activeProfile == null
                                ? null
                                : () => context
                                      .read<VpnConnectionBloc>()
                                      .add(const ConnectRequested()),
                            onDisconnect: () => context
                                .read<VpnConnectionBloc>()
                                .add(const DisconnectRequested()),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const SizedBox(height: LogConsole.collapsedHeight),
                      ],
                    ),
                  ),
                ),
                _Staggered(
                  animation: _entrance,
                  interval: _interval(OkoMotion.staggerLogConsole),
                  child: const LogConsole(),
                ),
                if (state.demoExpired && state.cooldownUntil != null)
                  DemoExpiredOverlay(cooldownUntil: state.cooldownUntil!),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NoServerCard extends StatelessWidget {
  const _NoServerCard({required this.tones, required this.textTheme});

  final OkoTones tones;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: tones.surfaceCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.dns_rounded, color: tones.textSecondary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Сервер не выбран',
                  style: textTheme.bodyMedium?.copyWith(
                    color: tones.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Выберите сервер, чтобы подключиться',
                  style: textTheme.bodySmall?.copyWith(
                    color: tones.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoSessionChip extends StatelessWidget {
  const _DemoSessionChip({required this.deadline});

  final DateTime deadline;

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: tones.surfaceElevated.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tones.glow),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hourglass_bottom_rounded,
            size: 16,
            color: tones.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            'Демо',
            style: textTheme.labelSmall?.copyWith(color: tones.textSecondary),
          ),
          const SizedBox(width: 10),
          DemoCountdown(
            deadline: deadline,
            style: textTheme.titleMedium?.copyWith(color: tones.textSecondary),
            warnStyle: textTheme.titleMedium?.copyWith(
              color: tones.accentTransitional,
            ),
          ),
        ],
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
