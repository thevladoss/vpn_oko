import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn_osin/core/theme/osin_motion.dart';
import 'package:vpn_osin/core/theme/osin_tones.dart';
import 'package:vpn_osin/core/theme/vpn_status.dart';
import 'package:vpn_osin/core/widgets/top_alert.dart';
import 'package:vpn_osin/core/widgets/top_alert_scope.dart';
import 'package:vpn_osin/features/server_config/domain/entities/server_profile.dart';
import 'package:vpn_osin/features/server_config/presentation/cubit/auto_switch_cubit.dart';
import 'package:vpn_osin/features/server_config/presentation/cubit/auto_switch_state.dart';
import 'package:vpn_osin/features/server_config/presentation/cubit/server_list_cubit.dart';
import 'package:vpn_osin/features/server_config/presentation/cubit/server_list_state.dart';
import 'package:vpn_osin/features/server_config/presentation/cubit/subscription_cubit.dart';
import 'package:vpn_osin/features/server_config/presentation/screens/server_management_sheet.dart';
import 'package:vpn_osin/features/vpn_connection/domain/usecases/resolve_active_vpn_config.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/bloc/vpn_connection_bloc.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/bloc/vpn_connection_event.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/bloc/vpn_connection_state.dart';
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
import 'package:vpn_osin/features/vpn_logs/presentation/widgets/log_console.dart';

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
  const VpnHomeScreen({required this.resolveConfig, super.key});

  final ResolveActiveVpnConfig resolveConfig;

  @override
  State<VpnHomeScreen> createState() => _VpnHomeScreenState();
}

class _VpnHomeScreenState extends State<VpnHomeScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _total = Duration(milliseconds: 590);
  static const double _kDemoChipSlot = 58;
  static const double _kCooldownSlot = 40;

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
    final active = activeServerProfile(context.read<ServerListCubit>().state);
    _syncAutoSwitchAvailability(active);
    unawaited(_dispatchActiveConfig(active));
  }

  void _syncAutoSwitchAvailability(ServerProfile? active) {
    context.read<AutoSwitchCubit>().setAvailable(
          available: active?.subscriptionId != null,
        );
  }

  Future<void> _dispatchActiveConfig(ServerProfile? active) async {
    final bloc = context.read<VpnConnectionBloc>();
    final config = await widget.resolveConfig(active);
    if (!mounted || bloc.isClosed) {
      return;
    }
    bloc.add(config == null ? const ConfigCleared() : ConfigSelected(config));
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Interval _interval(Duration start) {
    final begin = start.inMilliseconds / _total.inMilliseconds;
    final end =
        (start.inMilliseconds + OsinMotion.enterScreen.inMilliseconds) /
        _total.inMilliseconds;
    return Interval(begin, end, curve: OsinMotion.enterScreenCurve);
  }

  void _openServerSheet(BuildContext context) {
    final serverListCubit = context.read<ServerListCubit>();
    final subscriptionCubit = context.read<SubscriptionCubit>();
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: serverListCubit),
            BlocProvider.value(value: subscriptionCubit),
          ],
          child: const ServerManagementSheet(),
        ),
      ),
    );
  }

  VoidCallback? _irisToggle(VpnConnectionState state) {
    return switch (state.status) {
      VpnStatus.disconnected || VpnStatus.error =>
        state.cooldownActive
            ? null
            : () => context
                  .read<VpnConnectionBloc>()
                  .add(const ConnectRequested()),
      VpnStatus.connected => () => context
          .read<VpnConnectionBloc>()
          .add(const DisconnectRequested()),
      VpnStatus.connecting || VpnStatus.disconnecting => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final tones = context.osinTones;
    final textTheme = Theme.of(context).textTheme;
    return MultiBlocListener(
      listeners: [
        BlocListener<ServerListCubit, ServerListState>(
          listenWhen: (previous, current) {
            final before = activeServerProfile(previous);
            final after = activeServerProfile(current);
            return before?.id != after?.id ||
                before?.config != after?.config ||
                before?.subscriptionId != after?.subscriptionId;
          },
          listener: (context, serverState) {
            final active = activeServerProfile(serverState);
            _syncAutoSwitchAvailability(active);
            unawaited(_dispatchActiveConfig(active));
          },
        ),
        BlocListener<AutoSwitchCubit, AutoSwitchState>(
          listenWhen: (previous, current) =>
              previous.enabled != current.enabled,
          listener: (context, _) {
            final active = activeServerProfile(
              context.read<ServerListCubit>().state,
            );
            unawaited(_dispatchActiveConfig(active));
          },
        ),
        BlocListener<VpnConnectionBloc, VpnConnectionState>(
          listenWhen: (previous, current) =>
              current.noServerNudge != previous.noServerNudge,
          listener: (context, state) {
            unawaited(HapticFeedback.mediumImpact());
            TopAlertScope.of(context).show(
              VpnConnectionBloc.noServerHint,
              TopAlertKind.warning,
            );
          },
        ),
      ],
      child: Scaffold(
        body: BlocBuilder<VpnConnectionBloc, VpnConnectionState>(
          builder: (context, state) {
            final accent = tones.accentFor(state.status);
            final activeProfile = activeServerProfile(
              context.watch<ServerListCubit>().state,
            );
            final showDemoChip = state.status == VpnStatus.connected &&
                state.sessionEndsAt != null;
            final showCooldown = state.cooldownActive &&
                !state.demoExpired &&
                state.cooldownUntil != null;
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
                              OsinWordmark(status: state.status),
                              const Spacer(),
                              StatusBadge(status: state.status),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _Staggered(
                            animation: _entrance,
                            interval: _interval(OsinMotion.staggerIris),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: IrisIndicator(
                                status: state.status,
                                connectedSince: state.connectedSince,
                                onTap: _irisToggle(state),
                                nudge: state.noServerNudge,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: _kDemoChipSlot,
                          child: showDemoChip
                              ? Align(
                                  alignment: Alignment.topCenter,
                                  child: _DemoSessionChip(
                                    deadline: state.sessionEndsAt!,
                                  ),
                                )
                              : const SizedBox.shrink(),
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
                          interval: _interval(OsinMotion.staggerServerCard),
                          child: activeProfile != null
                              ? ServerCard(
                                  serverName: activeProfile.label,
                                  host: activeProfile.config.host,
                                  port: activeProfile.config.port,
                                  onTap: () => _openServerSheet(context),
                                )
                              : _NoServerCard(
                                  tones: tones,
                                  textTheme: textTheme,
                                  onTap: () => _openServerSheet(context),
                                ),
                        ),
                        if (activeProfile != null) ...[
                          const SizedBox(height: 12),
                          _Staggered(
                            animation: _entrance,
                            interval: _interval(
                              OsinMotion.staggerServerCard,
                            ),
                            child: const AutoSwitchToggle(),
                          ),
                        ],
                        const SizedBox(height: 24),
                        _Staggered(
                          animation: _entrance,
                          interval: _interval(OsinMotion.staggerTrafficPanel),
                          child: TrafficPanel(
                            rxBytes: state.rxBytes,
                            txBytes: state.txBytes,
                            status: state.status,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: _kCooldownSlot,
                          child: showCooldown
                              ? Align(
                                  alignment: Alignment.topCenter,
                                  child: CooldownNotice(
                                    cooldownUntil: state.cooldownUntil!,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        _Staggered(
                          animation: _entrance,
                          interval: _interval(OsinMotion.staggerConnectButton),
                          child: ConnectButton(
                            status: state.status,
                            onConnect: state.cooldownActive
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
                  interval: _interval(OsinMotion.staggerLogConsole),
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
  const _NoServerCard({
    required this.tones,
    required this.textTheme,
    this.onTap,
  });

  final OsinTones tones;
  final TextTheme textTheme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(24),
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
          if (onTap != null) ...[
            const SizedBox(width: 12),
            Icon(Icons.chevron_right_rounded, color: tones.textSecondary),
          ],
        ],
      ),
    );
    final decoration = BoxDecoration(
      color: tones.surfaceCard,
      borderRadius: BorderRadius.circular(20),
    );
    if (onTap == null) {
      return Container(decoration: decoration, child: content);
    }
    return Container(
      decoration: decoration,
      child: Semantics(
        button: true,
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: content,
          ),
        ),
      ),
    );
  }
}

class _DemoSessionChip extends StatelessWidget {
  const _DemoSessionChip({required this.deadline});

  final DateTime deadline;

  @override
  Widget build(BuildContext context) {
    final tones = context.osinTones;
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
        duration: OsinMotion.statusCrossfade,
        curve: OsinMotion.statusCrossfadeCurve,
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
