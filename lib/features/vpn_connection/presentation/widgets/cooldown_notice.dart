import 'package:flutter/material.dart';
import 'package:vpn_oko/core/theme/oko_tones.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/demo_countdown.dart';

class CooldownNotice extends StatelessWidget {
  const CooldownNotice({required this.cooldownUntil, super.key});

  final DateTime cooldownUntil;

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: tones.textSecondary);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_clock_rounded, size: 16, color: tones.textSecondary),
        const SizedBox(width: 6),
        Text('Доступно через ', style: muted),
        DemoCountdown(deadline: cooldownUntil, style: muted),
      ],
    );
  }
}
