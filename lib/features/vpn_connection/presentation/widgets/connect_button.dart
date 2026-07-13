import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vpn_oko/core/theme/oko_motion.dart';
import 'package:vpn_oko/core/theme/oko_tones.dart';
import 'package:vpn_oko/core/theme/vpn_status.dart';

class ConnectButton extends StatelessWidget {
  const ConnectButton({
    required this.status,
    this.onConnect,
    this.onDisconnect,
    super.key,
  });

  final VpnStatus status;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;

  String get _label => switch (status) {
        VpnStatus.disconnected => 'Connect',
        VpnStatus.connecting => 'Connecting…',
        VpnStatus.connected => 'Disconnect',
        VpnStatus.disconnecting => 'Disconnecting…',
        VpnStatus.error => 'Retry',
      };

  VoidCallback? get _onPressed => switch (status) {
        VpnStatus.disconnected || VpnStatus.error => onConnect,
        VpnStatus.connected => onDisconnect,
        VpnStatus.connecting || VpnStatus.disconnecting => null,
      };

  Color _background(OkoTones tones) => switch (status) {
        VpnStatus.disconnected => tones.accentConnected,
        VpnStatus.connecting ||
        VpnStatus.disconnecting =>
          tones.accentTransitional.withValues(alpha: 0.6),
        VpnStatus.connected => tones.surfaceElevated,
        VpnStatus.error => tones.accentError,
      };

  Color _foreground(OkoTones tones, ColorScheme scheme) =>
      status == VpnStatus.connected ? tones.accentError : scheme.onPrimary;

  BoxBorder? _border(OkoTones tones) => status == VpnStatus.connected
      ? Border.all(color: tones.accentError, width: 1.5)
      : null;

  Widget _leading(Color color) => switch (status) {
        VpnStatus.disconnected ||
        VpnStatus.connected =>
          Icon(Icons.power_settings_new_rounded, size: 20, color: color),
        VpnStatus.error => Icon(Icons.refresh_rounded, size: 20, color: color),
        VpnStatus.connecting ||
        VpnStatus.disconnecting =>
          _RunningSegment(color: color),
      };

  @override
  Widget build(BuildContext context) {
    final tones = Theme.of(context).extension<OkoTones>()!;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final foreground = _foreground(tones, scheme);
    final onPressed = _onPressed;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: _label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: OkoMotion.statusCrossfade,
        curve: OkoMotion.statusCrossfadeCurve,
        height: 56,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _background(tones),
          borderRadius: BorderRadius.circular(16),
          border: _border(tones),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed == null
                ? null
                : () {
                    unawaited(HapticFeedback.mediumImpact());
                    onPressed();
                  },
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _leading(foreground),
                  const SizedBox(width: 8),
                  AnimatedDefaultTextStyle(
                    duration: OkoMotion.statusCrossfade,
                    curve: OkoMotion.statusCrossfadeCurve,
                    style: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                    child: Text(_label),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RunningSegment extends StatefulWidget {
  const _RunningSegment({required this.color});

  final Color color;

  @override
  State<_RunningSegment> createState() => _RunningSegmentState();
}

class _RunningSegmentState extends State<_RunningSegment>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: OkoMotion.segment);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 4,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _SegmentPainter(
            progress: _controller.value,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

class _SegmentPainter extends CustomPainter {
  const _SegmentPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final track = Paint()..color = color.withValues(alpha: 0.3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      track,
    );

    final segWidth = size.width * 0.4;
    final travel = size.width + segWidth;
    final start = progress * travel - segWidth;
    final left = start.clamp(0.0, size.width);
    final right = (start + segWidth).clamp(0.0, size.width);
    if (right <= left) {
      return;
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(left, 0, right, size.height),
        radius,
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SegmentPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
