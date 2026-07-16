import 'package:flutter/material.dart';
import 'package:vpn_osin/core/theme/osin_motion.dart';
import 'package:vpn_osin/core/theme/osin_tones.dart';
import 'package:vpn_osin/core/theme/vpn_status.dart';

class OsinWordmark extends StatelessWidget {
  const OsinWordmark({required this.status, super.key});

  static const String _text = 'osın';

  final VpnStatus status;

  @override
  Widget build(BuildContext context) {
    final tones = context.osinTones;
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: tones.textPrimary,
        );
    final fontSize = style?.fontSize ?? 20;
    final dotSize = fontSize * 0.18;
    final direction = Directionality.of(context);
    final beforeDot = _width('os', style, direction);
    final throughDot = _width('osı', style, direction);
    final dotCenter = (beforeDot + throughDot) / 2;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Text(_text, style: style),
        Positioned(
          left: dotCenter - dotSize / 2,
          top: fontSize * 0.12,
          child: AnimatedContainer(
            duration: OsinMotion.statusCrossfade,
            curve: OsinMotion.statusCrossfadeCurve,
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: tones.accentFor(status),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  double _width(String text, TextStyle? style, TextDirection direction) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}
