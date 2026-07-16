import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vpn_osin/core/theme/osin_tones.dart';

class EmptyServerPasteField extends StatelessWidget {
  const EmptyServerPasteField({required this.onPaste, super.key});

  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    final tones = context.osinTones;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Добавьте свой первый сервер',
      child: CustomPaint(
        foregroundPainter: _DashedBorderPainter(
          color: tones.textSecondary,
          radius: 20,
        ),
        child: Material(
          color: tones.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              unawaited(HapticFeedback.mediumImpact());
              onPaste();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_rounded,
                    size: 32,
                    color: tones.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Добавьте свой первый сервер',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: tones.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Нажмите, чтобы вставить vless://-ссылку из буфера',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: tones.textSecondary,
                    ),
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

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _dash = 6;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5),
      Radius.circular(radius),
    );
    final source = Path()..addRRect(rrect);
    final dashed = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dash;
        dashed.addPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          Offset.zero,
        );
        distance = next + _gap;
      }
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
