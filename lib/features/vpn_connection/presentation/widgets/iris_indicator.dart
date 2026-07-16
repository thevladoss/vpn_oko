import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vpn_osin/core/theme/osin_motion.dart';
import 'package:vpn_osin/core/theme/osin_tones.dart';
import 'package:vpn_osin/core/theme/vpn_status.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/widgets/connection_timer.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/widgets/iris_painter.dart';

class IrisIndicator extends StatefulWidget {
  const IrisIndicator({
    required this.status,
    this.connectedSince,
    this.onTap,
    this.nudge = 0,
    super.key,
  });

  final VpnStatus status;
  final DateTime? connectedSince;
  final VoidCallback? onTap;
  final int nudge;

  @override
  State<IrisIndicator> createState() => _IrisIndicatorState();
}

class _IrisIndicatorState extends State<IrisIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _segment;
  late final AnimationController _breath;
  late final AnimationController _pupil;
  late final AnimationController _shake;
  late final CurvedAnimation _pupilCurve;

  VpnStatus? _appliedStatus;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _segment = AnimationController(vsync: this, duration: OsinMotion.segment);
    _breath = AnimationController(vsync: this, duration: OsinMotion.ringBreath);
    _pupil = AnimationController(vsync: this, duration: OsinMotion.pupilOpen);
    _shake = AnimationController(vsync: this, duration: OsinMotion.shake);
    _pupilCurve = CurvedAnimation(
      parent: _pupil,
      curve: OsinMotion.pupilOpenCurve,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    final statusChanged = _appliedStatus != widget.status;
    if (statusChanged || _reduceMotion != reduce) {
      _reduceMotion = reduce;
      _appliedStatus = widget.status;
      _applyStatus(oneShot: statusChanged);
    }
  }

  @override
  void didUpdateWidget(IrisIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _reduceMotion = MediaQuery.disableAnimationsOf(context);
      _appliedStatus = widget.status;
      _applyStatus(oneShot: true);
    }
    if (oldWidget.nudge != widget.nudge &&
        !MediaQuery.disableAnimationsOf(context)) {
      unawaited(_shake.forward(from: 0));
    }
  }

  void _applyStatus({required bool oneShot}) {
    _segment.stop();
    _breath.stop();
    if (_reduceMotion) {
      _shake.value = 0;
      _pupil.value = widget.status == VpnStatus.connected ? 1 : 0;
      if (oneShot) {
        _haptic();
      }
      return;
    }
    switch (widget.status) {
      case VpnStatus.connecting:
        unawaited(_segment.repeat());
        unawaited(_breath.repeat(reverse: true));
      case VpnStatus.connected:
        if (oneShot) {
          unawaited(_pupil.forward(from: 0));
        } else {
          _pupil.value = 1;
        }
        unawaited(_breath.repeat(reverse: true));
        if (oneShot) {
          _haptic();
        }
      case VpnStatus.error:
        if (oneShot) {
          unawaited(_shake.forward(from: 0));
          _haptic();
        }
      case VpnStatus.disconnected || VpnStatus.disconnecting:
        _pupil.value = 0;
    }
  }

  void _haptic() {
    switch (widget.status) {
      case VpnStatus.connected:
        unawaited(HapticFeedback.lightImpact());
      case VpnStatus.error:
        unawaited(HapticFeedback.heavyImpact());
      case _:
        break;
    }
  }

  String get _semanticsLabel => switch (widget.status) {
        VpnStatus.disconnected => 'VPN disconnected',
        VpnStatus.connecting => 'Connecting…',
        VpnStatus.connected => 'VPN connected',
        VpnStatus.disconnecting => 'Disconnecting',
        VpnStatus.error => 'Connection error',
      };

  @override
  void dispose() {
    _pupilCurve.dispose();
    _segment.dispose();
    _breath.dispose();
    _pupil.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tones = context.osinTones;
    final since =
        widget.status == VpnStatus.connected ? widget.connectedSince : null;
    final stack = Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: Listenable.merge(
            [_segment, _breath, _pupilCurve, _shake],
          ),
          builder: (context, _) => CustomPaint(
            painter: IrisPainter(
              status: widget.status,
              segment: _segment.value,
              breath: _breath.value,
              pupil: _pupilCurve.value,
              shake: _shake.value,
              accent: tones.accentFor(widget.status),
              glow: tones.glow,
            ),
          ),
        ),
        Center(child: ConnectionTimer(connectedSince: since)),
      ],
    );
    final onTap = widget.onTap;
    if (onTap == null) {
      return Semantics(
        liveRegion: true,
        label: _semanticsLabel,
        child: stack,
      );
    }
    return Semantics(
      button: true,
      enabled: true,
      label: _semanticsLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          unawaited(HapticFeedback.mediumImpact());
          onTap();
        },
        child: stack,
      ),
    );
  }
}
