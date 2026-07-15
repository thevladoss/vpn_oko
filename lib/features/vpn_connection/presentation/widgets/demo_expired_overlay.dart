import 'package:flutter/material.dart';
import 'package:vpn_oko/core/theme/oko_tones.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/demo_countdown.dart';

class DemoExpiredOverlay extends StatelessWidget {
  const DemoExpiredOverlay({required this.cooldownUntil, super.key});

  final DateTime cooldownUntil;

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    final textTheme = Theme.of(context).textTheme;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.72),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tones.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: tones.accentError.withValues(alpha: 0.4),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hourglass_bottom_rounded,
                      size: 40,
                      color: tones.accentError,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Вы исчерпали 5 минут демо подключения',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                        color: tones.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Снова доступно через',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: tones.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DemoCountdown(
                      deadline: cooldownUntil,
                      style: textTheme.headlineMedium?.copyWith(
                        color: tones.accentConnected,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
