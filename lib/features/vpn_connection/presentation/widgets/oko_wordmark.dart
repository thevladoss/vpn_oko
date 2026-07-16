import 'package:flutter/material.dart';
import 'package:vpn_osin/core/theme/oko_motion.dart';
import 'package:vpn_osin/core/theme/oko_tones.dart';
import 'package:vpn_osin/core/theme/vpn_status.dart';

class OkoWordmark extends StatelessWidget {
  const OkoWordmark({required this.status, super.key});

  final VpnStatus status;

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: tones.textPrimary,
        );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Text('oko', style: style),
        Positioned(
          top: -1,
          left: 3,
          child: AnimatedContainer(
            duration: OkoMotion.statusCrossfade,
            curve: OkoMotion.statusCrossfadeCurve,
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
