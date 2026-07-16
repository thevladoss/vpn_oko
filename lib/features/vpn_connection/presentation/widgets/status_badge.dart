import 'package:flutter/material.dart';
import 'package:vpn_osin/core/theme/oko_motion.dart';
import 'package:vpn_osin/core/theme/oko_tones.dart';
import 'package:vpn_osin/core/theme/vpn_status.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, super.key});

  final VpnStatus status;

  static const Map<VpnStatus, String> _words = {
    VpnStatus.disconnected: 'Disconnected',
    VpnStatus.connecting: 'Connecting',
    VpnStatus.connected: 'Connected',
    VpnStatus.disconnecting: 'Disconnecting',
    VpnStatus.error: 'Error',
  };

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    final accent = tones.accentFor(status);
    final style = Theme.of(context).textTheme.labelSmall ?? const TextStyle();
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: OkoMotion.statusCrossfade,
        curve: OkoMotion.statusCrossfadeCurve,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedDefaultTextStyle(
          duration: OkoMotion.statusCrossfade,
          curve: OkoMotion.statusCrossfadeCurve,
          style: style.copyWith(color: accent),
          child: Text(_words[status]!),
        ),
      ),
    );
  }
}
