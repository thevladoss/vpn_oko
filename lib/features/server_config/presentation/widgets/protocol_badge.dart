import 'package:flutter/material.dart';
import 'package:vpn_osin/core/theme/osin_tones.dart';

class ProtocolBadge extends StatelessWidget {
  const ProtocolBadge({required this.protocol, super.key});

  final String protocol;

  @override
  Widget build(BuildContext context) {
    final tones = context.osinTones;
    final accent = tones.accentIdle;
    final style = Theme.of(context).textTheme.labelSmall ?? const TextStyle();
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          protocol.toUpperCase(),
          style: style.copyWith(color: accent),
        ),
      ),
    );
  }
}
