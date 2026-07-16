import 'package:flutter/material.dart';
import 'package:vpn_osin/core/theme/osin_motion.dart';
import 'package:vpn_osin/core/theme/osin_tones.dart';
import 'package:vpn_osin/core/theme/vpn_status.dart';

class OsinWordmark extends StatelessWidget {
  const OsinWordmark({required this.status, super.key});

  final VpnStatus status;

  @override
  Widget build(BuildContext context) {
    final tones = context.osinTones;
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: tones.textPrimary,
        );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Text('osin', style: style),
        Positioned(
          top: -1,
          left: 3,
          child: AnimatedContainer(
            duration: OsinMotion.statusCrossfade,
            curve: OsinMotion.statusCrossfadeCurve,
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: tones.accentFor(status),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}
