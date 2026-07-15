import 'package:flutter/material.dart';
import 'package:vpn_oko/core/theme/oko_motion.dart';
import 'package:vpn_oko/core/theme/oko_tones.dart';

enum TopAlertKind { success, warning, error }

class TopAlert extends StatelessWidget {
  const TopAlert({
    required this.message,
    this.kind = TopAlertKind.success,
    this.visible = false,
    super.key,
  });

  final String? message;
  final TopAlertKind kind;
  final bool visible;

  Color _accent(OkoTones tones) => switch (kind) {
    TopAlertKind.success => tones.accentConnected,
    TopAlertKind.warning => tones.accentTransitional,
    TopAlertKind.error => tones.accentError,
  };

  IconData get _icon => switch (kind) {
    TopAlertKind.success => Icons.check_circle_rounded,
    TopAlertKind.warning => Icons.info_rounded,
    TopAlertKind.error => Icons.error_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    final textTheme = Theme.of(context).textTheme;
    final message = this.message;
    final accent = _accent(tones);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : OkoMotion.statusCrossfade;
    return IgnorePointer(
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, -0.4),
        duration: duration,
        curve: OkoMotion.statusCrossfadeCurve,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: duration,
          curve: OkoMotion.statusCrossfadeCurve,
          child: message == null
              ? const SizedBox.shrink()
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      accent.withValues(alpha: 0.16),
                      tones.surfaceElevated,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent),
                    boxShadow: [
                      BoxShadow(
                        color: tones.glow,
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(_icon, color: accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            message,
                            style: textTheme.bodyMedium?.copyWith(
                              color: tones.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
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
