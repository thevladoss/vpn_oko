import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vpn_osin/core/theme/vpn_status.dart';

class IrisPainter extends CustomPainter {
  const IrisPainter({
    required this.status,
    required this.segment,
    required this.breath,
    required this.pupil,
    required this.shake,
    required this.accent,
    required this.glow,
  });

  final VpnStatus status;
  final double segment;
  final double breath;
  final double pupil;
  final double shake;
  final Color accent;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final baseRadius = math.min(size.width, size.height) * 0.8 / 2;
    final displacement = status == VpnStatus.error
        ? math.sin(shake * math.pi * 6) * 8 * (1 - shake)
        : 0.0;
    final center = Offset(size.width / 2 + displacement, size.height / 2);
    final scale =
        status == VpnStatus.connecting ? 1 + (breath - 0.5) * 0.06 : 1.0;
    final radius = baseRadius * scale;

    _paintGlow(canvas, center, baseRadius);
    _paintRing(canvas, center, radius);
    _paintPupil(canvas, center, radius);
  }

  void _paintGlow(Canvas canvas, Offset center, double radius) {
    final alpha = _glowAlpha;
    if (alpha <= 0) {
      return;
    }
    final reach = radius * 1.4;
    final shader = RadialGradient(
      colors: [
        accent.withValues(alpha: alpha),
        glow.withValues(alpha: 0),
      ],
    ).createShader(Rect.fromCircle(center: center, radius: reach));
    canvas.drawCircle(center, reach, Paint()..shader = shader);
  }

  void _paintRing(Canvas canvas, Offset center, double radius) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _thickness
      ..color = accent;

    switch (status) {
      case VpnStatus.disconnected ||
            VpnStatus.connected ||
            VpnStatus.disconnecting:
        canvas.drawCircle(center, radius, ring);
      case VpnStatus.connecting:
        final dim = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _thickness
          ..color = accent.withValues(alpha: 0.35);
        canvas.drawCircle(center, radius, dim);
        const sweep = 40 * math.pi / 180;
        canvas.drawArc(rect, segment * 2 * math.pi, sweep, false, ring);
      case VpnStatus.error:
        const gap = 30 * math.pi / 180;
        canvas.drawArc(rect, gap / 2, 2 * math.pi - gap, false, ring);
    }
  }

  void _paintPupil(Canvas canvas, Offset center, double radius) {
    final inner = radius - _thickness - 4;
    final pupilRadius = math.max(radius * 0.04, inner * 0.5 * _pupilOpenness);
    final fill = Paint()..color = accent.withValues(alpha: 0.12);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = accent.withValues(alpha: 0.5);
    canvas
      ..drawCircle(center, pupilRadius, fill)
      ..drawCircle(center, pupilRadius, edge);
  }

  double get _thickness => switch (status) {
        VpnStatus.connected => 8,
        VpnStatus.disconnected => 3,
        _ => 5,
      };

  double get _glowAlpha => switch (status) {
        VpnStatus.connecting => 0.1,
        VpnStatus.connected => 0.1 + breath * 0.06,
        VpnStatus.disconnecting => 0.06,
        VpnStatus.error => 0.1,
        VpnStatus.disconnected => 0,
      };

  double get _pupilOpenness => switch (status) {
        VpnStatus.connected => pupil,
        VpnStatus.connecting => 0.5,
        VpnStatus.disconnecting => 0.3,
        VpnStatus.disconnected => 0,
        VpnStatus.error => 0,
      };

  @override
  bool shouldRepaint(IrisPainter oldDelegate) =>
      oldDelegate.status != status ||
      oldDelegate.segment != segment ||
      oldDelegate.breath != breath ||
      oldDelegate.pupil != pupil ||
      oldDelegate.shake != shake ||
      oldDelegate.accent != accent ||
      oldDelegate.glow != glow;
}
