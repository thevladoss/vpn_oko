import 'package:flutter/material.dart';
import 'package:vpn_osin/core/theme/oko_tones.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/widgets/demo_countdown.dart';

class CooldownNotice extends StatelessWidget {
  const CooldownNotice({required this.cooldownUntil, super.key});

  final DateTime cooldownUntil;

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: tones.accentTransitional);
    return Semantics(
      liveRegion: true,
      label: 'Кулдаун демо, повторное подключение будет доступно позже',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: tones.accentTransitional.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_clock_rounded,
              size: 16,
              color: tones.accentTransitional,
            ),
            const SizedBox(width: 6),
            Text('Доступно через ', style: labelStyle),
            DemoCountdown(deadline: cooldownUntil, style: labelStyle),
          ],
        ),
      ),
    );
  }
}
